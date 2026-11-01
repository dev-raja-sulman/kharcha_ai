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

  // Biometrics & Remember Me Preferences
  static const String _rememberEmailKey = 'kharcha_remember_email';
  static const String _biometricEnabledKey = 'kharcha_biometric_enabled';
  static const String _biometricUserEmailKey = 'kharcha_biometric_user_email';

  Future<void> saveRememberedEmail(String? email) async {
    if (email != null && email.isNotEmpty) {
      await _storage.write(key: _rememberEmailKey, value: email);
    } else {
      await _storage.delete(key: _rememberEmailKey);
    }
  }

  Future<String?> getRememberedEmail() async {
    try {
      return await _storage.read(key: _rememberEmailKey);
    } catch (_) {
      return null;
    }
  }

  Future<void> setBiometricEnabled(bool enabled, {String? email}) async {
    await _storage.write(key: _biometricEnabledKey, value: enabled ? 'true' : 'false');
    if (email != null) {
      await _storage.write(key: _biometricUserEmailKey, value: email);
    }
  }

  Future<bool> isBiometricEnabled() async {
    try {
      final val = await _storage.read(key: _biometricEnabledKey);
      return val == 'true';
    } catch (_) {
      return false;
    }
  }

  Future<String?> getBiometricEmail() async {
    try {
      return await _storage.read(key: _biometricUserEmailKey);
    } catch (_) {
      return null;
    }
  }
}
