import 'package:connectivity_plus/connectivity_plus.dart';

/// Stream-based connectivity monitoring for offline-first UX
class ConnectivityService {
  static final _instance = ConnectivityService._();
  late final Connectivity _connectivity;

  ConnectivityService._() {
    _connectivity = Connectivity();
  }

  factory ConnectivityService() => _instance;

  /// Stream of connectivity changes (true = online, false = offline)
  Stream<bool> get connectivityStream => _connectivity.onConnectivityChanged
      .map((result) => result != ConnectivityResult.none);

  /// Check current connectivity status
  Future<bool> get isOnline async {
    final result = await _connectivity.checkConnectivity();
    return result != ConnectivityResult.none;
  }
}
