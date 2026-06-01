import '../../../../core/errors/failures.dart';
import '../entities/auth_session.dart';
import '../repositories/auth_repository.dart';

/// Dev-only login bypassing Firebase OTP.
/// Guarded by assert() — compiled out of release builds.
class DevLoginUseCase {
  final AuthRepository _repo;
  const DevLoginUseCase(this._repo);

  Future<Result<AuthSession>> call({
    required String secret,
    required String phone,
    required String name,
  }) {
    // Defensive: refuse to even attempt if values are missing.
    if (secret.isEmpty) {
      return Future.value(
        Result.failure(ValidationFailure('Dev bypass secret missing')),
      );
    }
    return _repo.devLogin(secret: secret, phone: phone, name: name);
  }
}
