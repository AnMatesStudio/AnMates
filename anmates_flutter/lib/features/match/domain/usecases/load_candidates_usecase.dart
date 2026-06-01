import '../entities/match_candidate.dart';
import '../repositories/match_repository.dart';

class LoadCandidatesUseCase {
  final MatchRepository _repo;
  const LoadCandidatesUseCase(this._repo);

  Future<Result<List<MatchCandidate>>> call() => _repo.getCandidates();
}
