import '../repositories/auth_repository.dart';

class LogoutUseCase {
  final AuthRepository _repo;
  const LogoutUseCase(this._repo);

  Future<Result<void>> call() => _repo.logout();
}
