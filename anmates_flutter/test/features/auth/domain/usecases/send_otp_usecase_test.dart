import 'package:anmates/core/errors/failures.dart';
import 'package:anmates/features/auth/domain/entities/auth_session.dart';
import 'package:anmates/features/auth/domain/repositories/auth_repository.dart';
import 'package:anmates/features/auth/domain/usecases/send_otp_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late MockAuthRepository repo;
  late SendOtpUseCase useCase;

  setUp(() {
    repo = MockAuthRepository();
    useCase = SendOtpUseCase(repo);
  });

  group('SendOtpUseCase', () {
    test(
      'rejects phone numbers shorter than 10 chars after normalization',
      () async {
        final result = await useCase(phone: '123');

        expect(result.isSuccess, false);
        expect(result.failure, isA<ValidationFailure>());
        verifyNever(() => repo.sendOtp(phone: any(named: 'phone')));
      },
    );

    test(
      'normalizes local-format (0xx) to E.164 (+84xx) before calling repo',
      () async {
        when(() => repo.sendOtp(phone: any(named: 'phone'))).thenAnswer(
          (_) async => Result.success(
            const OtpSendResult(phone: '+84912345678', verificationId: 'vid-1'),
          ),
        );

        await useCase(phone: '0912345678');

        verify(() => repo.sendOtp(phone: '+84912345678')).called(1);
      },
    );

    test('keeps E.164 (+84xx) unchanged', () async {
      when(() => repo.sendOtp(phone: any(named: 'phone'))).thenAnswer(
        (_) async => Result.success(const OtpSendResult(phone: '+84912345678')),
      );

      await useCase(phone: '+84912345678');

      verify(() => repo.sendOtp(phone: '+84912345678')).called(1);
    });

    test('strips whitespace from input', () async {
      when(() => repo.sendOtp(phone: any(named: 'phone'))).thenAnswer(
        (_) async => Result.success(const OtpSendResult(phone: '+84912345678')),
      );

      await useCase(phone: '  091 234 5678 ');

      verify(() => repo.sendOtp(phone: '+84912345678')).called(1);
    });

    test('propagates repository failure', () async {
      when(() => repo.sendOtp(phone: any(named: 'phone'))).thenAnswer(
        (_) async =>
            Result.failure(const NetworkFailure(message: 'no network')),
      );

      final result = await useCase(phone: '0912345678');

      expect(result.isSuccess, false);
      expect(result.failure, isA<NetworkFailure>());
    });
  });
}
