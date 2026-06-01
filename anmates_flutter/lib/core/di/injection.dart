import 'package:get_it/get_it.dart';

import '../network/api_client.dart';
import '../network/connectivity_service.dart';
import '../storage/secure_storage_service.dart';

final getIt = GetIt.instance;

/// Initialize service locator with core dependencies
/// Call this once in main() before running the app
Future<void> setupDependencies() async {
  // Network & Storage (singletons — shared instances)
  getIt.registerSingleton<SecureStorageService>(SecureStorageService());

  getIt.registerSingleton<ApiClient>(ApiClient());

  getIt.registerSingleton<ConnectivityService>(ConnectivityService());

  // TODO: Register auth, discover, match, chat, etc. features when implemented
  // Each feature will have its own injection.dart that registers its repos +
  // usecases + blocs
}
