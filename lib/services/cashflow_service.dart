import 'package:dio/dio.dart';
import 'package:kharcha_ai/core/config/api_config.dart';
import 'package:kharcha_ai/core/network/api_client.dart';
import 'package:kharcha_ai/core/network/api_exception.dart';
import 'package:kharcha_ai/models/cashflow_model.dart';

class CashflowService {
  final ApiClient _apiClient;

  CashflowService({required ApiClient apiClient}) : _apiClient = apiClient;

  /// Retrieve monthly cashflow overview and health analysis
  Future<CashflowOverviewModel> getCashflowOverview({int? month, int? year}) async {
    try {
      final queryParams = <String, dynamic>{};
      if (month != null) queryParams['month'] = month;
      if (year != null) queryParams['year'] = year;

      final response = await _apiClient.dio.get(
        ApiConfig.cashflowUrl,
        queryParameters: queryParams,
      );

      return CashflowOverviewModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Failed to fetch cashflow overview: ${e.toString()}');
    }
  }
}
