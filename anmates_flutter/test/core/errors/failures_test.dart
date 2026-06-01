import 'package:anmates/core/errors/failures.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Failure Types', () {
    test('NetworkFailure stores message and status code', () {
      final failure = NetworkFailure(
        message: 'Connection failed',
        statusCode: 503,
      );

      expect(failure.message, 'Connection failed');
      expect(failure.statusCode, 503);
    });

    test('AuthFailure stores message and code', () {
      final failure = AuthFailure(
        message: 'Invalid token',
        code: 'token_expired',
      );

      expect(failure.message, 'Invalid token');
      expect(failure.code, 'token_expired');
    });

    test('ValidationFailure stores message', () {
      final failure = ValidationFailure('Phone number invalid');

      expect(failure.message, 'Phone number invalid');
    });

    test('ServerFailure stores message', () {
      final failure = ServerFailure('Internal server error');

      expect(failure.message, 'Internal server error');
    });

    test('DataParsingFailure for JSON errors', () {
      final failure = DataParsingFailure('Missing required field: userId');

      expect(failure.message, 'Missing required field: userId');
    });
  });
}
