import 'package:get_it/get_it.dart';

import '../../features/auth/auth_injection.dart';
import '../../features/match/match_injection.dart';
import '../network/api_client.dart';
import '../network/connectivity_service.dart';
import '../storage/secure_storage_service.dart';

final getIt = GetIt.instance;

/// Initialize service locator with core dependencies + feature registrations.
/// Call this once in main() before running the app.
Future<void> setupDependencies() async {
  // Core: Network & Storage (singletons — shared instances)
  getIt.registerSingleton<SecureStorageService>(SecureStorageService());
  getIt.registerSingleton<ApiClient>(ApiClient());
  getIt.registerSingleton<ConnectivityService>(ConnectivityService());

  // Features (register in dependency order: auth must come first since
  // other features may eventually need AuthRepository.currentUserId)
  registerAuthDependencies();
  registerMatchDependencies();

  // TODO Phase 5+: registerDiscoverDependencies(), registerChatDependencies()
}
