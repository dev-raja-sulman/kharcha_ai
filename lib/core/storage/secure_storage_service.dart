import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  static const String _tokenKey = 'kharcha_access_token';
  static const String _userCacheKey = 'kharcha_user_cached';

  final FlutterSecureStorage _storage;

  SecureStorageService({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
              iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
            );

  /// Save JWT Access Token to secure storage
  Future<void> saveToken(String token) async {
    await _storage.write(key: _tokenKey, value: token);
  }

  /// Retrieve stored JWT Access Token
  Future<String?> getToken() async {
    try {
      return await _storage.read(key: _tokenKey);
    } catch (_) {
      return null;
    }
  }

  /// Check whether an authentication token is present
  Future<bool> hasToken() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  /// Delete authentication token (called upon logout or token expiration)
  Future<void> deleteToken() async {
    try {
      await _storage.delete(key: _tokenKey);
    } catch (_) {}
  }

  /// Save raw user profile cache
  Future<void> saveUserCache(String userJson) async {
    await _storage.write(key: _userCacheKey, value: userJson);
  }

  /// Retrieve raw user profile cache
  Future<String?> getUserCache() async {
    try {
      return await _storage.read(key: _userCacheKey);
    } catch (_) {
      return null;
    }
  }

  /// Clear all stored session information
  Future<void> clearAll() async {
    try {
      await _storage.deleteAll();
    } catch (_) {
      await deleteToken();
    }
  }
}
