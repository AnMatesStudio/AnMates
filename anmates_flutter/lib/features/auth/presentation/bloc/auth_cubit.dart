import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/auth_session.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/usecases/check_auth_status_usecase.dart';
import '../../domain/usecases/dev_login_usecase.dart';
import '../../domain/usecases/logout_usecase.dart';
import '../../domain/usecases/send_otp_usecase.dart';
import '../../domain/usecases/verify_otp_usecase.dart';
import 'auth_state.dart';

/// AuthCubit orchestrates the auth flow.
///
/// Why a Cubit (not a Bloc)?
/// - All state transitions are simple sequential calls (send → otpSent →
///   verify → authenticated). No need for event transformers, debouncing,
///   or concurrent event handling.
///
/// Owns:
/// - All UseCases (no direct repository calls — Cubit talks to UseCases)
/// - Indirectly the AuthRepository lifecycle (calls dispose() on close)
class AuthCubit extends Cubit<AuthState> {
  final SendOtpUseCase _sendOtp;
  final VerifyOtpUseCase _verifyOtp;
  final DevLoginUseCase _devLogin;
  final LogoutUseCase _logout;
  final CheckAuthStatusUseCase _checkStatus;
  final AuthRepository _repository;

  AuthCubit({
    required SendOtpUseCase sendOtp,
    required VerifyOtpUseCase verifyOtp,
    required DevLoginUseCase devLogin,
    required LogoutUseCase logout,
    required CheckAuthStatusUseCase checkStatus,
    required AuthRepository repository,
  }) : _sendOtp = sendOtp,
       _verifyOtp = verifyOtp,
       _devLogin = devLogin,
       _logout = logout,
       _checkStatus = checkStatus,
       _repository = repository,
       super(const AuthInitial());

  /// On app start: emit Authenticated or Unauthenticated based on stored token.
  Future<void> checkStatus() async {
    final isAuth = await _checkStatus();
    if (isAuth) {
      final userId = await _repository.currentUserId() ?? '';
      // We don't have the full token here — emit a thin session marker.
      // API interceptors read the real token from SecureStorage, not from
      // this in-memory entity, so leaving accessToken empty is safe.
      emit(AuthAuthenticated(AuthSession(userId: userId, accessToken: '')));
    } else {
      emit(const AuthUnauthenticated());
    }
  }

  Future<void> sendOtp({required String phone}) async {
    emit(AuthSendingOtp(phone));
    final result = await _sendOtp(phone: phone);
    if (result.isSuccess) {
      final data = result.data!;
      if (data.isAutoVerified) {
        // Android instant verification path
        emit(const AuthVerifyingOtp());
        final session = await _repository.verifyWithIdToken(
          idToken: data.autoIdToken!,
        );
        if (session.isSuccess) {
          emit(AuthAuthenticated(session.data!));
        } else {
          emit(
            AuthError(
              message: session.failure!.message,
              previous: AuthOtpSent(phone: data.phone),
            ),
          );
        }
      } else {
        emit(
          AuthOtpSent(
            phone: data.phone,
            verificationId: data.verificationId,
            confirmationResult: data.confirmationResult,
          ),
        );
      }
    } else {
      emit(
        AuthError(
          message: result.failure!.message,
          previous: const AuthInitial(),
        ),
      );
    }
  }

  Future<void> verifyOtp({required String otpCode, String name = ''}) async {
    final current = state;
    if (current is! AuthOtpSent) {
      emit(
        AuthError(
          message: 'Phải gửi OTP trước khi xác thực',
          previous: current,
        ),
      );
      return;
    }
    emit(const AuthVerifyingOtp());
    final result = await _verifyOtp(
      phone: current.phone,
      otpCode: otpCode,
      verificationId: current.verificationId,
      confirmationResult: current.confirmationResult,
      name: name,
    );
    if (result.isSuccess) {
      emit(AuthAuthenticated(result.data!));
    } else {
      emit(AuthError(message: result.failure!.message, previous: current));
    }
  }

  Future<void> devLogin({
    required String secret,
    required String phone,
    required String name,
  }) async {
    emit(AuthSendingOtp(phone));
    final result = await _devLogin(secret: secret, phone: phone, name: name);
    if (result.isSuccess) {
      emit(AuthAuthenticated(result.data!));
    } else {
      emit(
        AuthError(
          message: result.failure!.message,
          previous: const AuthInitial(),
        ),
      );
    }
  }

  Future<void> logout() async {
    await _logout();
    emit(const AuthUnauthenticated());
  }

  @override
  Future<void> close() {
    _repository.dispose();
    return super.close();
  }
}
