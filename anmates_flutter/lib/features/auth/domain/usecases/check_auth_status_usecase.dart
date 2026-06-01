import '../repositories/auth_repository.dart';

class CheckAuthStatusUseCase {
  final AuthRepository _repo;
  const CheckAuthStatusUseCase(this._repo);

  Future<bool> call() => _repo.isLoggedIn();
}
