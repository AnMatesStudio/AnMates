import '../../core/di/injection.dart';
import '../../core/storage/secure_storage_service.dart';
import 'data/datasources/auth_firebase_datasource.dart';
import 'data/datasources/auth_remote_datasource.dart';
import 'data/repositories/auth_repository_impl.dart';
import 'domain/repositories/auth_repository.dart';
import 'domain/usecases/check_auth_status_usecase.dart';
import 'domain/usecases/dev_login_usecase.dart';
import 'domain/usecases/logout_usecase.dart';
import 'domain/usecases/send_otp_usecase.dart';
import 'domain/usecases/verify_otp_usecase.dart';
import 'presentation/bloc/auth_cubit.dart';

/// Register all auth-feature dependencies into the global service locator.
/// Called from core/di/injection.dart after core services are registered.
void registerAuthDependencies() {
  // Datasources (singletons — share Dio + Firebase instances)
  getIt.registerLazySingleton<AuthRemoteDataSource>(
    () => AuthRemoteDataSource(),
  );
  getIt.registerLazySingleton<AuthFirebaseDataSource>(
    () => AuthFirebaseDataSource(),
  );

  // Repository — singleton; manages RecaptchaVerifier lifecycle so it must
  // be unique across the app.
  getIt.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(
      firebase: getIt<AuthFirebaseDataSource>(),
      remote: getIt<AuthRemoteDataSource>(),
      storage: getIt<SecureStorageService>(),
    ),
  );

  // UseCases — stateless; factory is fine but lazySingleton avoids
  // re-creating tiny objects on every Cubit construction.
  getIt.registerLazySingleton(() => SendOtpUseCase(getIt<AuthRepository>()));
  getIt.registerLazySingleton(() => VerifyOtpUseCase(getIt<AuthRepository>()));
  getIt.registerLazySingleton(() => DevLoginUseCase(getIt<AuthRepository>()));
  getIt.registerLazySingleton(() => LogoutUseCase(getIt<AuthRepository>()));
  getIt.registerLazySingleton(
    () => CheckAuthStatusUseCase(getIt<AuthRepository>()),
  );

  // Cubit — factory so each BlocProvider gets a fresh instance.
  getIt.registerFactory(
    () => AuthCubit(
      sendOtp: getIt<SendOtpUseCase>(),
      verifyOtp: getIt<VerifyOtpUseCase>(),
      devLogin: getIt<DevLoginUseCase>(),
      logout: getIt<LogoutUseCase>(),
      checkStatus: getIt<CheckAuthStatusUseCase>(),
      repository: getIt<AuthRepository>(),
    ),
  );
}
