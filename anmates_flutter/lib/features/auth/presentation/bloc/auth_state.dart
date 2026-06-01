import '../../domain/entities/auth_session.dart';

/// Sealed AuthState hierarchy. Using a sealed class instead of freezed
/// (added later) so the Phase 2 PR doesn't require codegen wiring.
sealed class AuthState {
  const AuthState();
}

/// Before anything has happened (e.g., on app launch, before checkAuthStatus).
class AuthInitial extends AuthState {
  const AuthInitial();
}

/// Sending OTP (loading indicator on Phone screen).
class AuthSendingOtp extends AuthState {
  final String phone;
  const AuthSendingOtp(this.phone);
}

/// OTP sent successfully — navigate to OTP entry screen.
/// Carries the verification context needed for the verify call.
class AuthOtpSent extends AuthState {
  final String phone;
  final String? verificationId;
  final Object? confirmationResult;
  const AuthOtpSent({
    required this.phone,
    this.verificationId,
    this.confirmationResult,
  });
}

/// Verifying OTP code (loading indicator on OTP screen).
class AuthVerifyingOtp extends AuthState {
  const AuthVerifyingOtp();
}

/// Logged in successfully — navigate to main app.
class AuthAuthenticated extends AuthState {
  final AuthSession session;
  const AuthAuthenticated(this.session);
}

/// Logged out / never logged in.
class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();
}

/// Recoverable error — show snackbar + stay on current screen.
/// The previous (non-error) state carries context for resuming the flow.
class AuthError extends AuthState {
  final String message;
  final String? code;
  final AuthState previous;
  const AuthError({required this.message, this.code, required this.previous});
}
