/// Immutable auth session — what the app knows after a successful login.
/// Domain entity (no JSON, no Flutter imports).
class AuthSession {
  final String userId;
  final String accessToken;
  final String? refreshToken;
  final String? displayName;

  const AuthSession({
    required this.userId,
    required this.accessToken,
    this.refreshToken,
    this.displayName,
  });

  @override
  bool operator ==(Object other) =>
      other is AuthSession &&
      other.userId == userId &&
      other.accessToken == accessToken &&
      other.refreshToken == refreshToken &&
      other.displayName == displayName;

  @override
  int get hashCode =>
      Object.hash(userId, accessToken, refreshToken, displayName);
}

/// Result of a phone-OTP send request. Different shape on web vs mobile:
/// - Web uses ConfirmationResult (opaque handle to Firebase JS)
/// - Mobile uses verificationId (string token)
/// - Android instant-verify path returns an auto-resolved ID token directly
class OtpSendResult {
  final String phone;
  final String? verificationId; // mobile flow
  final Object?
  confirmationResult; // web flow (typed loosely to keep domain Firebase-free)
  final String? autoIdToken; // Android instant verify

  const OtpSendResult({
    required this.phone,
    this.verificationId,
    this.confirmationResult,
    this.autoIdToken,
  });

  bool get isAutoVerified => autoIdToken != null;
}
