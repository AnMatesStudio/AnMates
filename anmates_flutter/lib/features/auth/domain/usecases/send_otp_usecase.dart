import '../../../../core/errors/failures.dart';
import '../entities/auth_session.dart';
import '../repositories/auth_repository.dart';

/// Send OTP to a phone number.
/// Encapsulates validation logic so widgets never call the repo directly.
class SendOtpUseCase {
  final AuthRepository _repo;
  const SendOtpUseCase(this._repo);

  Future<Result<OtpSendResult>> call({required String phone}) async {
    final normalized = _normalize(phone);
    if (normalized.length < 10) {
      return Result.failure(ValidationFailure('Số điện thoại không hợp lệ'));
    }
    return _repo.sendOtp(phone: normalized);
  }

  /// Convert local-format (0xxxxxxxxx) into E.164 (+84xxxxxxxxx).
  /// Pure function — easy to test.
  String _normalize(String raw) {
    final cleaned = raw.replaceAll(RegExp(r'\s+'), '');
    if (cleaned.startsWith('+')) return cleaned;
    if (cleaned.startsWith('0')) return '+84${cleaned.substring(1)}';
    return '+84$cleaned';
  }
}
