import 'package:anmates/core/errors/failures.dart';
import 'package:anmates/features/auth/domain/entities/auth_session.dart';
import 'package:anmates/features/auth/domain/repositories/auth_repository.dart';
import 'package:anmates/features/auth/domain/usecases/verify_otp_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late MockAuthRepository repo;
  late VerifyOtpUseCase useCase;

  setUp(() {
    repo = MockAuthRepository();
    useCase = VerifyOtpUseCase(repo);
  });

  group('VerifyOtpUseCase', () {
    test('rejects OTP codes that are not exactly 6 digits', () async {
      final result = await useCase(phone: '+84912345678', otpCode: '12345');

      expect(result.isSuccess, false);
      expect(result.failure, isA<ValidationFailure>());
      verifyNever(
        () => repo.verifyOtp(
          phone: any(named: 'phone'),
          otpCode: any(named: 'otpCode'),
          verificationId: any(named: 'verificationId'),
          confirmationResult: any(named: 'confirmationResult'),
          name: any(named: 'name'),
        ),
      );
    });

    test('rejects OTP with non-digit characters', () async {
      final result = await useCase(phone: '+84912345678', otpCode: '12abcd');

      expect(result.isSuccess, false);
      expect(result.failure, isA<ValidationFailure>());
    });

    test('passes valid 6-digit OTP through to repository', () async {
      const session = AuthSession(userId: 'u1', accessToken: 'tok');
      when(
        () => repo.verifyOtp(
          phone: any(named: 'phone'),
          otpCode: any(named: 'otpCode'),
          verificationId: any(named: 'verificationId'),
          confirmationResult: any(named: 'confirmationResult'),
          name: any(named: 'name'),
        ),
      ).thenAnswer((_) async => Result.success(session));

      final result = await useCase(
        phone: '+84912345678',
        otpCode: '123456',
        verificationId: 'vid-1',
      );

      expect(result.isSuccess, true);
      expect(result.data, session);
      verify(
        () => repo.verifyOtp(
          phone: '+84912345678',
          otpCode: '123456',
          verificationId: 'vid-1',
          confirmationResult: null,
          name: '',
        ),
      ).called(1);
    });
  });
}
