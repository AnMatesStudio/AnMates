import '../../../../core/errors/failures.dart';
import '../entities/auth_session.dart';
import '../repositories/auth_repository.dart';

/// Verify a 6-digit OTP code and return an AuthSession.
class VerifyOtpUseCase {
  final AuthRepository _repo;
  const VerifyOtpUseCase(this._repo);

  Future<Result<AuthSession>> call({
    required String phone,
    required String otpCode,
    String? verificationId,
    Object? confirmationResult,
    String name = '',
  }) async {
    if (otpCode.length != 6 || !RegExp(r'^\d{6}$').hasMatch(otpCode)) {
      return Result.failure(ValidationFailure('Mã OTP phải gồm 6 chữ số'));
    }
    return _repo.verifyOtp(
      phone: phone,
      otpCode: otpCode,
      verificationId: verificationId,
      confirmationResult: confirmationResult,
      name: name,
    );
  }
}
