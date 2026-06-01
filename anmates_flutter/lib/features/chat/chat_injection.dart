import '../../core/di/injection.dart';
import '../../core/storage/secure_storage_service.dart';
import 'data/datasources/chat_remote_datasource.dart';
import 'data/datasources/chat_websocket_datasource.dart';
import 'data/repositories/chat_repository_impl.dart';
import 'domain/repositories/chat_repository.dart';
import 'presentation/bloc/chat_detail_cubit.dart';
import 'presentation/bloc/chat_list_cubit.dart';

/// Register chat feature dependencies.
void registerChatDependencies() {
  getIt.registerLazySingleton<ChatRemoteDataSource>(
    () => ChatRemoteDataSource(),
  );
  // ChatWebSocketDataSource is a Factory: each ChatDetailCubit instance owns
  // its own WS lifecycle. If two ChatDetailViews could ever be open
  // simultaneously (e.g., split screen on tablet) they need independent WS.
  getIt.registerFactory<ChatWebSocketDataSource>(
    () => ChatWebSocketDataSource(storage: getIt<SecureStorageService>()),
  );
  getIt.registerFactory<ChatRepository>(
    () => ChatRepositoryImpl(
      remote: getIt<ChatRemoteDataSource>(),
      ws: getIt<ChatWebSocketDataSource>(),
    ),
  );
  getIt.registerFactory(() => ChatListCubit(getIt<ChatRepository>()));
  getIt.registerFactory(() => ChatDetailCubit(getIt<ChatRepository>()));
}
