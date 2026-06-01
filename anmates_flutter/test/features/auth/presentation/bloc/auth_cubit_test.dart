import 'package:anmates/core/errors/failures.dart';
import 'package:anmates/features/auth/domain/entities/auth_session.dart';
import 'package:anmates/features/auth/domain/repositories/auth_repository.dart';
import 'package:anmates/features/auth/domain/usecases/check_auth_status_usecase.dart';
import 'package:anmates/features/auth/domain/usecases/dev_login_usecase.dart';
import 'package:anmates/features/auth/domain/usecases/logout_usecase.dart';
import 'package:anmates/features/auth/domain/usecases/send_otp_usecase.dart';
import 'package:anmates/features/auth/domain/usecases/verify_otp_usecase.dart';
import 'package:anmates/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:anmates/features/auth/presentation/bloc/auth_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late MockAuthRepository repo;
  late SendOtpUseCase sendOtp;
  late VerifyOtpUseCase verifyOtp;
  late DevLoginUseCase devLogin;
  late LogoutUseCase logout;
  late CheckAuthStatusUseCase checkStatus;
  late AuthCubit cubit;

  setUp(() {
    repo = MockAuthRepository();
    sendOtp = SendOtpUseCase(repo);
    verifyOtp = VerifyOtpUseCase(repo);
    devLogin = DevLoginUseCase(repo);
    logout = LogoutUseCase(repo);
    checkStatus = CheckAuthStatusUseCase(repo);

    when(() => repo.dispose()).thenReturn(null);

    cubit = AuthCubit(
      sendOtp: sendOtp,
      verifyOtp: verifyOtp,
      devLogin: devLogin,
      logout: logout,
      checkStatus: checkStatus,
      repository: repo,
    );
  });

  tearDown(() => cubit.close());

  group('AuthCubit.sendOtp', () {
    test(
      'emits [SendingOtp, OtpSent] when repo returns verificationId',
      () async {
        when(() => repo.sendOtp(phone: any(named: 'phone'))).thenAnswer(
          (_) async => Result.success(
            const OtpSendResult(phone: '+84912345678', verificationId: 'vid-1'),
          ),
        );

        final emitted = <AuthState>[];
        final sub = cubit.stream.listen(emitted.add);

        await cubit.sendOtp(phone: '0912345678');
        await Future<void>.delayed(Duration.zero);
        await sub.cancel();

        expect(emitted, hasLength(2));
        expect(emitted[0], isA<AuthSendingOtp>());
        expect(emitted[1], isA<AuthOtpSent>());
        expect((emitted[1] as AuthOtpSent).verificationId, 'vid-1');
      },
    );

    test('emits AuthError when repo returns failure', () async {
      when(() => repo.sendOtp(phone: any(named: 'phone'))).thenAnswer(
        (_) async =>
            Result.failure(const AuthFailure(message: 'invalid phone')),
      );

      final emitted = <AuthState>[];
      final sub = cubit.stream.listen(emitted.add);

      await cubit.sendOtp(phone: '0912345678');
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      expect(emitted.last, isA<AuthError>());
      expect((emitted.last as AuthError).message, 'invalid phone');
    });
  });

  group('AuthCubit.verifyOtp', () {
    test('refuses to verify when state is not AuthOtpSent', () async {
      final emitted = <AuthState>[];
      final sub = cubit.stream.listen(emitted.add);

      await cubit.verifyOtp(otpCode: '123456');
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      expect(emitted, hasLength(1));
      expect(emitted.first, isA<AuthError>());
    });

    test(
      'emits [VerifyingOtp, Authenticated] on successful verification',
      () async {
        // Set state to AuthOtpSent first
        when(() => repo.sendOtp(phone: any(named: 'phone'))).thenAnswer(
          (_) async => Result.success(
            const OtpSendResult(phone: '+84912345678', verificationId: 'vid-1'),
          ),
        );
        await cubit.sendOtp(phone: '+84912345678');

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

        final emitted = <AuthState>[];
        final sub = cubit.stream.listen(emitted.add);

        await cubit.verifyOtp(otpCode: '123456');
        await Future<void>.delayed(Duration.zero);
        await sub.cancel();

        expect(emitted, hasLength(2));
        expect(emitted[0], isA<AuthVerifyingOtp>());
        expect(emitted[1], isA<AuthAuthenticated>());
      },
    );
  });

  group('AuthCubit.logout', () {
    test('emits AuthUnauthenticated after logout', () async {
      when(
        () => repo.logout(),
      ).thenAnswer((_) async => const Result<void>.success(null));

      final emitted = <AuthState>[];
      final sub = cubit.stream.listen(emitted.add);

      await cubit.logout();
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      expect(emitted.last, isA<AuthUnauthenticated>());
    });
  });

  group('AuthCubit.checkStatus', () {
    test('emits Authenticated when token exists', () async {
      when(() => repo.isLoggedIn()).thenAnswer((_) async => true);
      when(() => repo.currentUserId()).thenAnswer((_) async => 'u123');

      final emitted = <AuthState>[];
      final sub = cubit.stream.listen(emitted.add);

      await cubit.checkStatus();
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      expect(emitted.last, isA<AuthAuthenticated>());
      expect((emitted.last as AuthAuthenticated).session.userId, 'u123');
    });

    test('emits Unauthenticated when no token', () async {
      when(() => repo.isLoggedIn()).thenAnswer((_) async => false);

      final emitted = <AuthState>[];
      final sub = cubit.stream.listen(emitted.add);

      await cubit.checkStatus();
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      expect(emitted.last, isA<AuthUnauthenticated>());
    });
  });

  group('AuthCubit.close', () {
    test('disposes repository (releases RecaptchaVerifier)', () async {
      await cubit.close();

      verify(() => repo.dispose()).called(1);
    });
  });
}
