import 'package:dio/dio.dart';
import 'package:kharcha_ai/core/config/api_config.dart';
import 'package:kharcha_ai/core/network/auth_interceptor.dart';
import 'package:kharcha_ai/core/storage/secure_storage_service.dart';

class ApiClient {
  late final Dio dio;
  final SecureStorageService storage;

  ApiClient({
    required this.storage,
    Dio? customDio,
    OnSessionExpired? onSessionExpired,
  }) {
    dio = customDio ??
        Dio(
          BaseOptions(
            baseUrl: ApiConfig.baseUrl,
            connectTimeout: ApiConfig.connectTimeout,
            receiveTimeout: ApiConfig.receiveTimeout,
            sendTimeout: ApiConfig.sendTimeout,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            // TLS verification is enabled by default in Dio; we safely maintain it
          ),
        );

    dio.interceptors.add(
      AuthInterceptor(
        storage: storage,
        onSessionExpired: onSessionExpired,
      ),
    );
  }
}
