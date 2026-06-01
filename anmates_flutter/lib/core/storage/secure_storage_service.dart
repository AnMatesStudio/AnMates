import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Encrypted token storage using platform-native security:
/// - iOS: Keychain with kSecAttrAccessibleFirstUnlock
/// - Android: EncryptedSharedPreferences with AES-256-GCM
class SecureStorageService {
  static const _accessTokenKey = 'access_token';
  static const _refreshTokenKey = 'refresh_token';

  final FlutterSecureStorage _storage;

  SecureStorageService({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(encryptedSharedPreferences: true),
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.first_unlock,
            ),
          );

  /// Save tokens after authentication
  Future<void> saveTokens({
    required String accessToken,
    String? refreshToken,
  }) async {
    await Future.wait([
      _storage.write(key: _accessTokenKey, value: accessToken),
      if (refreshToken != null)
        _storage.write(key: _refreshTokenKey, value: refreshToken),
    ]);
  }

  /// Retrieve access token for API requests
  Future<String?> get accessToken => _storage.read(key: _accessTokenKey);

  /// Retrieve refresh token for token renewal
  Future<String?> get refreshToken => _storage.read(key: _refreshTokenKey);

  /// Update access token (e.g., after refresh)
  Future<void> updateAccessToken(String newToken) =>
      _storage.write(key: _accessTokenKey, value: newToken);

  /// Generic read of any secure key.
  Future<String?> read(String key) => _storage.read(key: key);

  /// Generic write of any secure key.
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  /// Generic delete of any secure key.
  Future<void> delete(String key) => _storage.delete(key: key);

  /// Clear all stored tokens on logout
  Future<void> clearAll() => _storage.deleteAll();
}
