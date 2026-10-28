import 'package:dio/dio.dart';
import 'package:kharcha_ai/core/storage/secure_storage_service.dart';

typedef OnSessionExpired = void Function();

class AuthInterceptor extends QueuedInterceptor {
  final SecureStorageService _storage;
  final OnSessionExpired? onSessionExpired;

  AuthInterceptor({
    required SecureStorageService storage,
    this.onSessionExpired,
  }) : _storage = storage;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Check if Authorization header is already provided manually
    if (!options.headers.containsKey('Authorization')) {
      final token = await _storage.getToken();
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }
    return handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    // If request returned 401 Unauthorized and was not a login attempt
    if (err.response?.statusCode == 401 && !err.requestOptions.path.contains('/auth/login')) {
      // Clear expired token
      await _storage.deleteToken();
      onSessionExpired?.call();
    }
    return handler.next(err);
  }
}
