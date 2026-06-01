import 'package:anmates/core/storage/secure_storage_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockFlutterSecureStorage extends Mock implements FlutterSecureStorage {}

void main() {
  group('SecureStorageService', () {
    late MockFlutterSecureStorage mockStorage;
    late SecureStorageService service;

    setUp(() {
      mockStorage = MockFlutterSecureStorage();
      service = SecureStorageService(storage: mockStorage);
    });

    test('saveTokens writes both access and refresh tokens', () async {
      when(
        () => mockStorage.write(
          key: any(named: 'key'),
          value: any(named: 'value'),
        ),
      ).thenAnswer((_) async {});

      await service.saveTokens(
        accessToken: 'access_123',
        refreshToken: 'refresh_456',
      );

      verify(
        () =>
            mockStorage.write(key: 'access_token', value: 'access_123'),
      ).called(1);

      verify(
        () =>
            mockStorage.write(key: 'refresh_token', value: 'refresh_456'),
      ).called(1);
    });

    test('saveTokens writes only access token if refresh is null', () async {
      when(
        () => mockStorage.write(
          key: any(named: 'key'),
          value: any(named: 'value'),
        ),
      ).thenAnswer((_) async {});

      await service.saveTokens(accessToken: 'access_123');

      verify(
        () =>
            mockStorage.write(key: 'access_token', value: 'access_123'),
      ).called(1);

      verifyNever(
        () => mockStorage.write(
          key: 'refresh_token',
          value: any(named: 'value'),
        ),
      );
    });

    test('accessToken returns stored token', () async {
      when(
        () => mockStorage.read(key: 'access_token'),
      ).thenAnswer((_) async => 'token_value');

      final token = await service.accessToken;

      expect(token, 'token_value');
      verify(() => mockStorage.read(key: 'access_token')).called(1);
    });

    test('accessToken returns null if not found', () async {
      when(
        () => mockStorage.read(key: 'access_token'),
      ).thenAnswer((_) async => null);

      final token = await service.accessToken;

      expect(token, null);
    });

    test('updateAccessToken overwrites existing token', () async {
      when(
        () => mockStorage.write(
          key: any(named: 'key'),
          value: any(named: 'value'),
        ),
      ).thenAnswer((_) async {});

      await service.updateAccessToken('new_token');

      verify(
        () =>
            mockStorage.write(key: 'access_token', value: 'new_token'),
      ).called(1);
    });

    test('clearAll deletes all stored data', () async {
      when(() => mockStorage.deleteAll()).thenAnswer((_) async {});

      await service.clearAll();

      verify(() => mockStorage.deleteAll()).called(1);
    });
  });
}
