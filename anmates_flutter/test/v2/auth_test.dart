import 'dart:convert';

import 'package:anmates/services/api_client.dart';
import 'package:anmates/services/auth_service.dart';
import 'package:anmates/views/v2/v2_app.dart';
import 'package:anmates/views/v2/v2_data.dart';
import 'package:flutter/services.dart';
import 'package:anmates/views/v2/v2_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Đăng nhập / Đăng ký (email + password) through the real shell; only the API
/// server is faked. Returns the call log as "METHOD path body".
List<String> serveAuthApi({int loginStatus = 200, int registerStatus = 201}) {
  final calls = <String>[];
  var signedIn = false;
  http.Response json(Object? data, int status) => http.Response(
        jsonEncode(status < 300
            ? {'success': true, 'data': data}
            : {'success': false, 'error': {'message': 'HTTP $status'}}),
        status,
        headers: {'content-type': 'application/json'},
      );
  const tokens = {
    'access_token': 'acc',
    'refresh_token': 'ref',
    'user': {'id': 'u-me', 'name': 'Huy', 'onboarding_done': false},
  };
  final client = MockClient((req) async {
    calls.add('${req.method} ${req.url.path} ${req.body}'.trim());
    switch ((req.method, req.url.path)) {
      case ('POST', '/api/v1/auth/login'):
        signedIn = loginStatus == 200;
        return json(tokens, loginStatus);
      case ('POST', '/api/v1/auth/register'):
        signedIn = registerStatus == 201;
        return json(tokens, registerStatus);
      case ('POST', '/api/v1/auth/logout'):
        signedIn = false;
        return json({'ok': true}, 200);
      case ('GET', '/api/v1/profile'):
        return signedIn ? json({'id': 'u-me', 'name': 'Huy'}, 200) : json(null, 401);
      case ('GET', '/api/v1/conversations'):
        return signedIn ? json([], 200) : json(null, 401);
      case ('GET', '/api/v1/matches'):
        return signedIn ? json([], 200) : json(null, 401);
      default:
        return json(null, 404);
    }
  });
  AuthService().httpClient = client;
  ApiClient().httpClient = client;
  return calls;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<V2State> pumpApp(WidgetTester tester, V2Screen start) async {
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

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('sign up: name, email, password → signed in, on Home', (tester) async {
    final calls = serveAuthApi();
    final s = await pumpApp(tester, V2Screen.onb);
    s.openAuth(register: true);
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Tạo tài khoản'), findsOneWidget);
    await tester.enterText(find.descendant(of: find.byKey(const Key('auth-name')), matching: find.byType(TextField)), 'Huy');
    await tester.enterText(find.descendant(of: find.byKey(const Key('auth-email')), matching: find.byType(TextField)), ' Huy@Mail.com ');
    await tester.enterText(find.descendant(of: find.byKey(const Key('auth-password')), matching: find.byType(TextField)), 'matkhau1234');
    await tester.tap(find.byKey(const Key('auth-submit')));
    await settle(tester);

    expect(calls, contains('POST /api/v1/auth/register {"email":"Huy@Mail.com","password":"matkhau1234","name":"Huy"}'));
    expect(s.signedIn, isTrue);
    expect(s.profileName, 'Huy');
    expect(s.screen, V2Screen.home);
    expect((await SharedPreferences.getInstance()).getString('access_token'), 'acc');
  });

  testWidgets('signed out, no Tôi tab and no avatar; signing in brings both back', (tester) async {
    serveAuthApi();
    final s = await pumpApp(tester, V2Screen.home);
    await settle(tester);
    expect(find.text('Tôi'), findsNothing);
    expect(find.byKey(const Key('home-avatar')), findsNothing);
    expect(find.text('Tin nhắn'), findsOneWidget);

    s.openAuth();
    await s.submitAuth(email: 'huy@mail.com', password: 'matkhau1234');
    await tester.pump(const Duration(milliseconds: 300));
    expect(s.screen, V2Screen.home);
    expect(find.text('Tôi'), findsOneWidget);
    expect(find.byKey(const Key('home-avatar')), findsOneWidget);

    await s.signOut();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Tôi'), findsNothing);
  });

  test('the account avatar is the bundled chibi illustration, not a photo', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    expect(A.avatar, 'assets/v2/avatar-chibi.png');
    expect((await rootBundle.load(A.avatar)).lengthInBytes, greaterThan(10000));
  });

  testWidgets('a short password is caught before any request', (tester) async {
    final calls = serveAuthApi();
    final s = await pumpApp(tester, V2Screen.onb);
    s.openAuth(register: true);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.enterText(find.descendant(of: find.byKey(const Key('auth-name')), matching: find.byType(TextField)), 'Huy');
    await tester.enterText(find.descendant(of: find.byKey(const Key('auth-email')), matching: find.byType(TextField)), 'huy@mail.com');
    await tester.enterText(find.descendant(of: find.byKey(const Key('auth-password')), matching: find.byType(TextField)), 'ngan');
    await tester.tap(find.byKey(const Key('auth-submit')));
    await settle(tester);

    expect(find.text('Mật khẩu cần ít nhất 10 ký tự.'), findsOneWidget);
    expect(calls.where((c) => c.contains('/auth/')), isEmpty);
    expect(s.screen, V2Screen.auth);
  });

  test('wrong password and a taken email get their own messages', () async {
    serveAuthApi(loginStatus: 401);
    final s = V2State()..openAuth();
    await s.submitAuth(email: 'huy@mail.com', password: 'sai-mat-khau');
    expect(s.authError, 'Sai email hoặc mật khẩu.');
    expect(s.signedIn, isFalse);
    expect(s.screen, V2Screen.auth);

    serveAuthApi(registerStatus: 409);
    s.setAuthRegister(true);
    await s.submitAuth(email: 'huy@mail.com', password: 'matkhau1234', name: 'Huy');
    expect(s.authError, 'Email này đã có tài khoản — đăng nhập nhé.');
  });

  testWidgets('from the signed-out inbox, sign in lands back on the inbox', (tester) async {
    serveAuthApi();
    final s = await pumpApp(tester, V2Screen.inbox);
    await settle(tester);
    expect(find.text('Đăng nhập để nhắn tin'), findsOneWidget);

    await tester.tap(find.byKey(const Key('inbox-primary-action')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(s.screen, V2Screen.auth);
    expect(find.text('Đăng nhập'), findsWidgets);

    await tester.enterText(find.descendant(of: find.byKey(const Key('auth-email')), matching: find.byType(TextField)), 'huy@mail.com');
    await tester.enterText(find.descendant(of: find.byKey(const Key('auth-password')), matching: find.byType(TextField)), 'matkhau1234');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settle(tester);

    expect(s.screen, V2Screen.inbox);
    expect(find.text('Chưa có cuộc trò chuyện nào'), findsOneWidget);
  });

  test('back from sign-in returns where it came from; sign out forgets the account', () async {
    final calls = serveAuthApi();
    final s = V2State()..go(V2Screen.me);
    s.openAuth(then: V2Screen.me);
    s.authCancel();
    expect(s.screen, V2Screen.me);

    s.openAuth(then: V2Screen.me);
    await s.submitAuth(email: 'huy@mail.com', password: 'x');
    expect(s.signedIn, isTrue);
    expect(s.screen, V2Screen.me);

    s.go(V2Screen.onb);
    s.openAuth(); // signed in already: no form, straight in
    expect(s.screen, V2Screen.home);

    await s.signOut();
    expect(calls, contains(startsWith('POST /api/v1/auth/logout')));
    expect(s.signedIn, isFalse);
    expect((await SharedPreferences.getInstance()).getString('access_token'), isNull);
  });
}
