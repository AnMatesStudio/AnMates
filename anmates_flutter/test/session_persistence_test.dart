import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:anmates/services/api_client.dart';
import 'package:anmates/services/auth_service.dart';

/// Tests for the "keep me logged in" session-persistence fix:
///   - AuthService.refreshSession() exchanges the stored refresh token.
///   - ApiClient silently refreshes + replays a request on a 401.
/// Both back the splash-screen session restore so F5 / revisit no longer drops
/// the user back into onboarding. See
/// sessions/2026-06-07-session-persistence-keep-logged-in.md.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  String tokenEnvelope({
    required String access,
    required String refresh,
    bool onboardingDone = true,
  }) => jsonEncode({
    'success': true,
    'data': {
      'access_token': access,
      'refresh_token': refresh,
      'user': {'id': 'u1', 'onboarding_done': onboardingDone},
    },
  });

  String errorEnvelope(String message) => jsonEncode({
    'success': false,
    'error': {'message': message},
  });

  group('AuthService.refreshSession', () {
    test('exchanges a valid refresh token and persists the new pair', () async {
      SharedPreferences.setMockInitialValues({
        'access_token': 'old_access',
        'refresh_token': 'valid_refresh',
        'user_id': 'u1',
        'onboarding_done': false,
      });

      var refreshCalls = 0;
      AuthService().httpClient = MockClient((req) async {
        if (req.url.path.endsWith('/auth/refresh')) {
          refreshCalls++;
          expect(jsonDecode(req.body)['refresh_token'], 'valid_refresh');
          return http.Response(
            tokenEnvelope(access: 'new_access', refresh: 'new_refresh'),
            200,
          );
        }
        return http.Response('{}', 404);
      });

      final ok = await AuthService().refreshSession();

      expect(ok, isTrue);
      expect(refreshCalls, 1);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('access_token'), 'new_access');
      expect(prefs.getString('refresh_token'), 'new_refresh');
      // Refresh response also re-syncs the server's onboarding flag.
      expect(prefs.getBool('onboarding_done'), isTrue);
    });

    test('returns false when the server rejects the refresh token', () async {
      SharedPreferences.setMockInitialValues({
        'refresh_token': 'expired_refresh',
      });
      AuthService().httpClient = MockClient(
        (req) async =>
            http.Response(errorEnvelope('invalid refresh token'), 401),
      );

      expect(await AuthService().refreshSession(), isFalse);
    });

    test(
      'returns false without any network call when no refresh token',
      () async {
        SharedPreferences.setMockInitialValues({});
        var hitNetwork = false;
        AuthService().httpClient = MockClient((req) async {
          hitNetwork = true;
          return http.Response('{}', 200);
        });

        expect(await AuthService().refreshSession(), isFalse);
        expect(hitNetwork, isFalse);
      },
    );
  });

  group('ApiClient silent refresh-on-401', () {
    test(
      'refreshes once then replays the request with the new token',
      () async {
        SharedPreferences.setMockInitialValues({
          'access_token': 'expired_access',
          'refresh_token': 'valid_refresh',
        });

        var protectedCalls = 0;
        var refreshCalls = 0;
        final mock = MockClient((req) async {
          if (req.url.path.endsWith('/auth/refresh')) {
            refreshCalls++;
            return http.Response(
              tokenEnvelope(access: 'fresh_access', refresh: 'fresh_refresh'),
              200,
            );
          }
          protectedCalls++;
          final auth = req.headers['Authorization'];
          if (auth == 'Bearer expired_access') {
            return http.Response(errorEnvelope('token expired'), 401);
          }
          // The replay must carry the freshly minted access token.
          expect(auth, 'Bearer fresh_access');
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {'name': 'An', 'onboarding_done': true},
            }),
            200,
          );
        });
        ApiClient().httpClient = mock;
        AuthService().httpClient = mock;

        final data = await ApiClient().get('/api/v1/profile');

        expect((data as Map)['name'], 'An');
        expect(refreshCalls, 1, reason: 'exactly one refresh');
        expect(protectedCalls, 2, reason: 'original 401 + one replay');
      },
    );

    test('propagates the 401 when the refresh token is also expired', () async {
      SharedPreferences.setMockInitialValues({
        'access_token': 'expired_access',
        'refresh_token': 'expired_refresh',
      });

      final mock = MockClient((req) async {
        if (req.url.path.endsWith('/auth/refresh')) {
          return http.Response(errorEnvelope('invalid refresh token'), 401);
        }
        return http.Response(errorEnvelope('token expired'), 401);
      });
      ApiClient().httpClient = mock;
      AuthService().httpClient = mock;

      await expectLater(
        ApiClient().get('/api/v1/profile'),
        throwsA(
          isA<ApiException>().having((e) => e.statusCode, 'statusCode', 401),
        ),
      );
    });
  });
}
