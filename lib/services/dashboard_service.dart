import 'package:dio/dio.dart';
import 'package:kharcha_ai/core/network/api_client.dart';
import 'package:kharcha_ai/core/network/api_exception.dart';
import 'package:kharcha_ai/models/dashboard_model.dart';

class DashboardService {
  final ApiClient apiClient;

  DashboardService({required this.apiClient});

  Future<DashboardFinancialSummaryModel> getFinancialSummary({
    int? month,
    int? year,
    String? currency,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (month != null) queryParams['month'] = month;
      if (year != null) queryParams['year'] = year;
      if (currency != null && currency.isNotEmpty) queryParams['currency'] = currency;

      final response = await apiClient.dio.get(
        '/api/v1/dashboard/financial-summary',
        queryParameters: queryParams,
      );

      return DashboardFinancialSummaryModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}
