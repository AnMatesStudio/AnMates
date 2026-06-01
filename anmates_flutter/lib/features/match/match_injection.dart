import '../../core/di/injection.dart';
import 'data/datasources/match_remote_datasource.dart';
import 'data/repositories/match_repository_impl.dart';
import 'domain/repositories/match_repository.dart';
import 'domain/usecases/load_candidates_usecase.dart';
import 'domain/usecases/swipe_usecase.dart';
import 'presentation/bloc/match_cubit.dart';

/// Register all match-feature dependencies into the global service locator.
/// Called from core/di/injection.dart after auth is registered (so any
/// match flow can look up the current user via AuthRepository if needed).
void registerMatchDependencies() {
  getIt.registerLazySingleton<MatchRemoteDataSource>(
    () => MatchRemoteDataSource(),
  );
  getIt.registerLazySingleton<MatchRepository>(
    () => MatchRepositoryImpl(remote: getIt<MatchRemoteDataSource>()),
  );
  getIt.registerLazySingleton(
    () => LoadCandidatesUseCase(getIt<MatchRepository>()),
  );
  getIt.registerLazySingleton(() => SwipeUseCase(getIt<MatchRepository>()));
  getIt.registerFactory(
    () => MatchCubit(
      loadCandidates: getIt<LoadCandidatesUseCase>(),
      swipe: getIt<SwipeUseCase>(),
    ),
  );
}
