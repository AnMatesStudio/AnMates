import '../../../../core/errors/failures.dart';
import '../entities/auth_session.dart';

/// Either-style result without dartz dependency (kept simple for now).
/// Use the `success` getter to branch on success/failure.
class Result<T> {
  final T? data;
  final Failure? failure;
  const Result.success(T this.data) : failure = null;
  const Result.failure(Failure this.failure) : data = null;
  bool get isSuccess => failure == null;
}

/// Auth domain contract — implementations live in data/ layer.
/// All methods return Result<T> so callers never deal with raw exceptions.
abstract class AuthRepository {
  /// Send OTP to the given phone number.
  /// Platform-specific behavior handled by implementation:
  /// - Web: builds RecaptchaVerifier, returns ConfirmationResult
  /// - Mobile: triggers Firebase verifyPhoneNumber, returns verificationId
  Future<Result<OtpSendResult>> sendOtp({required String phone});

  /// Verify the OTP code and authenticate with backend.
  /// Returns the resulting AuthSession on success.
  Future<Result<AuthSession>> verifyOtp({
    required String phone,
    required String otpCode,
    String? verificationId,
    Object? confirmationResult,
    String name,
  });

  /// Verify directly with a Firebase ID token (used for Android auto-verify
  /// path or dev bypass on backend).
  Future<Result<AuthSession>> verifyWithIdToken({
    required String idToken,
    String name,
  });

  /// Dev-only: skip Firebase and go straight to backend with shared secret.
  /// Backend must have DEV_MODE=true.
  Future<Result<AuthSession>> devLogin({
    required String secret,
    required String phone,
    required String name,
  });

  /// Clear all tokens locally and call backend logout endpoint.
  Future<Result<void>> logout();

  /// Check if a session exists in secure storage.
  Future<bool> isLoggedIn();

  /// Read current user id from session (null if not logged in).
  Future<String?> currentUserId();

  /// Cleanup any platform resources (e.g., the web RecaptchaVerifier).
  /// Called when the auth UI is disposed to release the DOM widget.
  void dispose();
}
