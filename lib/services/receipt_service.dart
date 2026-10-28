import 'package:dio/dio.dart';
import 'package:kharcha_ai/core/config/api_config.dart';
import 'package:kharcha_ai/core/network/api_client.dart';
import 'package:kharcha_ai/core/network/api_exception.dart';
import 'package:kharcha_ai/models/receipt_scan_model.dart';

class ReceiptScannerService {
  final ApiClient _apiClient;

  ReceiptScannerService({required ApiClient apiClient}) : _apiClient = apiClient;

  /// Scans a receipt image using the authenticated backend endpoint.
  /// Does NOT create an expense in the database; returns structured preview data.
  Future<ReceiptScanModel> scanReceiptBytes({
    required List<int> bytes,
    required String filename,
    String? providerOverride,
  }) async {
    try {
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(
          bytes,
          filename: filename,
        ),
      });

      final queryParams = <String, dynamic>{};
      if (providerOverride != null && providerOverride.isNotEmpty) {
        queryParams['provider'] = providerOverride;
      }

      final response = await _apiClient.dio.post(
        ApiConfig.receiptScanUrl,
        data: formData,
        queryParameters: queryParams,
        options: Options(
          contentType: 'multipart/form-data',
        ),
      );

      return ReceiptScanModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Failed to process receipt: ${e.toString()}');
    }
  }
}
