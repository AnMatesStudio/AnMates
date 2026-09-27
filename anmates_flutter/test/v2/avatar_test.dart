import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:anmates/services/api_client.dart';
import 'package:anmates/views/v2/v2_app.dart';
import 'package:anmates/views/v2/v2_data.dart';
import 'package:anmates/views/v2/v2_kit.dart';
import 'package:anmates/views/v2/v2_state.dart';
import 'package:anmates/widgets/v2/photo_viewer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Stands in for `/profile` and `/profile/avatar`, keeping one avatar_url.
class FakeProfileApi {
  FakeProfileApi({this.avatarUrl, this.failWrites = false}) {
    ApiClient().httpClient = MockClient((req) async {
      http.Response json(Object? data, [int status = 200]) => http.Response(
            jsonEncode(status < 300
                ? {'success': true, 'data': data}
                : {'success': false, 'error': {'message': 'HTTP $status'}}),
            status,
            headers: {'content-type': 'application/json'},
          );
      Map<String, dynamic> profile() => {'id': 'u-me', 'name': 'Huy', 'avatar_url': avatarUrl};
      switch ((req.method, req.url.path)) {
        case ('GET', '/api/v1/profile'):
          return json(profile());
        case ('PUT', '/api/v1/profile'):
          puts.add(jsonDecode(req.body) as Map<String, dynamic>);
          if (failWrites) return json(null, 500);
          final v = puts.last['avatar_url'] as String?;
          if (v != null) avatarUrl = v.isEmpty ? null : v;
          return json(profile());
        case ('PUT', '/api/v1/profile/avatar'):
          uploads.add(base64Decode((jsonDecode(req.body) as Map)['image_base64'] as String));
          if (failWrites) return json(null, 500);
          avatarUrl = '/api/v1/users/u-me/avatar?v=abcdef012345';
          return json(profile());
        default:
          return json(<String, dynamic>{}, 200);
      }
    });
  }

  String? avatarUrl;
  final bool failWrites;
  final puts = <Map<String, dynamic>>[];
  final uploads = <Uint8List>[];
}

/// A 600×400 PNG, like a photo from the gallery.
Future<Uint8List> photoPng() async {
  final rec = ui.PictureRecorder();
  Canvas(rec).drawRect(const Rect.fromLTWH(0, 0, 600, 400), Paint()..color = const Color(0xFF3366CC));
  final img = await rec.endRecording().toImage(600, 400);
  return (await img.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('avatar sources', () {
    test('an uploaded photo is served by our API; a sample is a bundled asset', () {
      expect(avatarSourceOf('/api/v1/users/u/avatar?v=abc'),
          (network: ApiClient.mediaUrl('/api/v1/users/u/avatar?v=abc'), asset: null));
      expect(ApiClient.mediaUrl('/api/v1/users/u/avatar?v=abc'), endsWith('/api/v1/users/u/avatar?v=abc'));
      expect(ApiClient.mediaUrl('/api/v1/users/u/avatar?v=abc'), startsWith('http'));
      expect(avatarSourceOf('asset:assets/v2/avatars/sample-3.png'),
          (network: null, asset: 'assets/v2/avatars/sample-3.png'));
      expect(avatarSourceOf('https://cdn.example/a.jpg'), (network: 'https://cdn.example/a.jpg', asset: null));
      expect(avatarSourceOf(null), (network: null, asset: null));
      expect(avatarSourceOf(''), (network: null, asset: null));
    });

    test('the samples are the chibi plus the ten illustrations', () {
      expect(kAvatarSamples, hasLength(11));
      expect(kAvatarSamples.first, A.avatar);
      expect(kAvatarSamples.last, 'assets/v2/avatars/sample-10.png');
    });

    testWidgets("a mate's avatar shows a sample they picked", (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: MateAvatar(name: 'Lan', userId: 'u-lan', url: 'asset:assets/v2/avatars/sample-2.png'),
      ));
      final img = tester.widget<Image>(find.byType(Image));
      expect((img.image as AssetImage).assetName, 'assets/v2/avatars/sample-2.png');
    });
  });

  group('saving', () {
    test('the profile brings the avatar in', () async {
      FakeProfileApi(avatarUrl: 'asset:assets/v2/avatars/sample-4.png');
      final s = V2State();
      await s.loadProfile();
      expect(s.myAvatarUrl, 'asset:assets/v2/avatars/sample-4.png');
    });

    test('picking a sample saves it as an asset: avatar_url', () async {
      final api = FakeProfileApi();
      final s = V2State();
      expect(await s.chooseAvatarSample('assets/v2/avatars/sample-3.png'), isTrue);
      expect(api.puts.single, {'avatar_url': 'asset:assets/v2/avatars/sample-3.png'});
      expect(s.myAvatarUrl, 'asset:assets/v2/avatars/sample-3.png');
      expect(s.avatarError, isNull);
    });

    test('an upload sends the crop and takes the URL the server gives back', () async {
      final api = FakeProfileApi();
      final s = V2State();
      final bytes = Uint8List.fromList([1, 2, 3, 4]);
      expect(await s.uploadAvatarCrop(bytes), isTrue);
      expect(api.uploads.single, bytes);
      expect(s.myAvatarUrl, '/api/v1/users/u-me/avatar?v=abcdef012345');
    });

    test('a failed save keeps the old avatar and says so', () async {
      FakeProfileApi(avatarUrl: 'asset:assets/v2/avatars/sample-1.png', failWrites: true);
      final s = V2State();
      await s.loadProfile();
      expect(await s.chooseAvatarSample('assets/v2/avatars/sample-5.png'), isFalse);
      expect(await s.uploadAvatarCrop(Uint8List.fromList([1])), isFalse);
      expect(s.myAvatarUrl, 'asset:assets/v2/avatars/sample-1.png');
      expect(s.avatarError, isNotNull);
      expect(s.avatarSaving, isFalse);
    });
  });

  group('screens', () {
    Future<V2State> pumpMe(WidgetTester tester, FakeProfileApi api) async {
      tester.view.physicalSize = const Size(402, 874);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final s = V2State();
      await s.loadProfile();
      s.go(V2Screen.me);
      await tester.pumpWidget(MaterialApp(
        home: ChangeNotifierProvider<V2State>.value(value: s, child: const V2AppBody()),
      ));
      await tester.pump(const Duration(milliseconds: 300));
      return s;
    }

    Future<void> tap(WidgetTester tester, Finder f) async {
      await tester.ensureVisible(f);
      await tester.pump();
      await tester.tap(f);
      await tester.pump(const Duration(milliseconds: 300));
    }

    String? assetShownIn(WidgetTester tester, Finder scope) {
      final imgs = tester.widgetList<Image>(find.descendant(of: scope, matching: find.byType(Image)));
      for (final i in imgs) {
        if (i.image is AssetImage) return (i.image as AssetImage).assetName;
      }
      return null;
    }

    testWidgets('Me → avatar → pick a sample → save → Me shows it', (tester) async {
      final api = FakeProfileApi();
      final s = await pumpMe(tester, api);
      expect(assetShownIn(tester, find.byKey(const Key('me-avatar'))), A.avatar); // the default

      await tap(tester, find.byKey(const Key('me-avatar')));
      expect(s.screen, V2Screen.avatar);
      expect(find.text('Ảnh đại diện'), findsOneWidget);
      expect(find.text('Tải ảnh lên'), findsOneWidget);
      for (var i = 0; i < kAvatarSamples.length; i++) {
        expect(find.byKey(Key('avatar-sample-$i')), findsOneWidget);
      }

      await tap(tester, find.byKey(const Key('avatar-sample-3')));
      await tap(tester, find.text('Lưu ảnh đại diện'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(api.puts.single, {'avatar_url': 'asset:${kAvatarSamples[3]}'});
      expect(s.screen, V2Screen.me);
      expect(assetShownIn(tester, find.byKey(const Key('me-avatar'))), kAvatarSamples[3]);
    });

    testWidgets('upload → crop and zoom → use it → a 512 px square is sent', (tester) async {
      final api = FakeProfileApi();
      final s = await pumpMe(tester, api);
      final png = await tester.runAsync(photoPng);
      s.avatarPickerForTest = () async => png;

      await tap(tester, find.byKey(const Key('me-avatar')));
      await tester.runAsync(() async {
        await tester.tap(find.text('Tải ảnh lên'));
        await Future<void>.delayed(const Duration(milliseconds: 200)); // decode
      });
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byKey(const Key('avatar-cropper')), findsOneWidget);
      expect(find.text('Chọn ảnh khác'), findsOneWidget);
      // Zoom in with the + button; the slider follows.
      final before = tester.widget<Slider>(find.byKey(const Key('avatar-zoom'))).value;
      await tap(tester, find.byKey(const Key('avatar-zoom-in')));
      expect(tester.widget<Slider>(find.byKey(const Key('avatar-zoom'))).value, greaterThan(before));

      await tester.runAsync(() async {
        await tester.tap(find.text('Dùng ảnh này'));
        await Future<void>.delayed(const Duration(milliseconds: 300)); // render + encode
      });
      await tester.pump(const Duration(milliseconds: 300));

      expect(api.uploads, hasLength(1));
      final sent = await tester.runAsync(() async =>
          (await (await ui.instantiateImageCodec(api.uploads.single)).getNextFrame()).image);
      expect((sent!.width, sent.height), (512, 512));
      expect(s.myAvatarUrl, '/api/v1/users/u-me/avatar?v=abcdef012345');
      expect(s.screen, V2Screen.me);
    });

    testWidgets('the back button leaves without saving', (tester) async {
      final api = FakeProfileApi();
      final s = await pumpMe(tester, api);
      await tap(tester, find.byKey(const Key('me-avatar')));
      await tap(tester, find.byKey(const Key('avatar-sample-5')));
      await tap(tester, find.byType(V2BackButton));
      expect(s.screen, V2Screen.me);
      expect(api.puts, isEmpty);
    });

    group('full-size view (uploaded photos only)', () {
      const uploaded = '/api/v1/users/u-me/avatar?v=abcdef012345';

      Future<V2State> pumpAvatarScreen(WidgetTester tester, String? avatarUrl) async {
        final s = await pumpMe(tester, FakeProfileApi(avatarUrl: avatarUrl));
        await tap(tester, find.byKey(const Key('me-avatar')));
        expect(s.screen, V2Screen.avatar);
        return s;
      }

      testWidgets('my uploaded photo opens full screen, and closes', (tester) async {
        await pumpAvatarScreen(tester, uploaded);
        // The badge that says it opens (the aria-label is checked in tool/e2e/ui_avatar.js).
        expect(find.byIcon(Icons.zoom_out_map_rounded), findsOneWidget);

        await tap(tester, find.byKey(const Key('avatar-preview')));
        final viewer = tester.widget<PhotoViewer>(find.byType(PhotoViewer));
        expect(viewer.photos, [ApiClient.mediaUrl(uploaded)]);

        await tap(tester, find.byKey(const Key('photo-viewer-close')));
        expect(find.byType(PhotoViewer), findsNothing);
      });

      testWidgets('an illustration, or the default, has no full-size view', (tester) async {
        for (final url in ['asset:assets/v2/avatars/sample-2.png', null]) {
          await pumpAvatarScreen(tester, url);
          expect(find.byIcon(Icons.zoom_out_map_rounded), findsNothing);
          await tap(tester, find.byKey(const Key('avatar-preview')));
          expect(find.byType(PhotoViewer), findsNothing, reason: '$url');
        }
      });

      testWidgets('picking an illustration over my photo turns the view off', (tester) async {
        await pumpAvatarScreen(tester, uploaded);
        await tap(tester, find.byKey(const Key('avatar-sample-4')));
        await tap(tester, find.byKey(const Key('avatar-preview')));
        expect(find.byType(PhotoViewer), findsNothing);
      });

      testWidgets("a mate's uploaded photo opens full screen from the chat header", (tester) async {
        final s = await pumpMe(tester, FakeProfileApi());
        Mate mate(String? url) => Mate(
              userId: 'u-lan', name: 'Lan', img: A.hotpot, match: 80,
              overlapFoods: const ['lau'], tags: const [], avatarUrl: url,
            );

        s
          ..go(V2Screen.swipe)
          ..seedMatchReveal(mate(uploaded.replaceFirst('u-me', 'u-lan')), sample: true)
          ..openMatchChat();
        await tester.pump(const Duration(milliseconds: 300));
        await tap(tester, find.byKey(const Key('chat-partner-avatar')));
        expect(tester.widget<PhotoViewer>(find.byType(PhotoViewer)).photos,
            [ApiClient.mediaUrl('/api/v1/users/u-lan/avatar?v=abcdef012345')]);
        await tap(tester, find.byKey(const Key('photo-viewer-close')));

        s
          ..go(V2Screen.swipe)
          ..seedMatchReveal(mate('asset:assets/v2/avatars/sample-1.png'), sample: true)
          ..openMatchChat();
        await tester.pump(const Duration(milliseconds: 300));
        await tap(tester, find.byKey(const Key('chat-partner-avatar')));
        expect(find.byType(PhotoViewer), findsNothing);
      });
    });

    testWidgets('Explore header shows my avatar', (tester) async {
      final s = await pumpMe(tester, FakeProfileApi(avatarUrl: 'asset:assets/v2/avatars/sample-7.png'));
      s.go(V2Screen.home);
      await tester.pump(const Duration(milliseconds: 300));
      expect(assetShownIn(tester, find.byKey(const Key('home-avatar'))), 'assets/v2/avatars/sample-7.png');
    });
  });
}
