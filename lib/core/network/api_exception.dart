import 'package:dio/dio.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic details;

  ApiException({
    required this.message,
    this.statusCode,
    this.details,
  });

  factory ApiException.fromDio(DioException error) => ApiException.fromDioError(error);

  factory ApiException.fromDioError(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return ApiException(
          message: 'Connection timed out. Please check your internet connection.',
          statusCode: error.response?.statusCode,
        );

      case DioExceptionType.connectionError:
        return ApiException(
          message: 'Cannot reach KharchaAI backend. Ensure the server is running and the device is on the same network.',
          statusCode: error.response?.statusCode,
        );

      case DioExceptionType.badResponse:
        final status = error.response?.statusCode;
        final data = error.response?.data;
        String errorMessage = 'Request failed with status code $status';

        if (data is Map<String, dynamic> && data.containsKey('detail')) {
          final detail = data['detail'];
          if (detail is String) {
            errorMessage = detail;
          } else if (detail is List && detail.isNotEmpty) {
            // FastAPI validation error array
            final firstError = detail.first;
            if (firstError is Map && firstError.containsKey('msg')) {
              errorMessage = firstError['msg'].toString();
            }
          }
        } else if (status == 401) {
          errorMessage = 'Invalid email or password. Please try again.';
        } else if (status == 403) {
          errorMessage = 'Access denied. Your account may be deactivated.';
        } else if (status == 404) {
          errorMessage = 'Requested resource not found.';
        } else if (status != null && status >= 500) {
          errorMessage = 'Internal server error. Please try again shortly.';
        }

        return ApiException(
          message: errorMessage,
          statusCode: status,
          details: data,
        );

      case DioExceptionType.cancel:
        return ApiException(message: 'Request was cancelled.');

      default:
        return ApiException(
          message: 'An unexpected network error occurred: ${error.message ?? 'Unknown error'}',
        );
    }
  }

  @override
  String toString() => message;
}
