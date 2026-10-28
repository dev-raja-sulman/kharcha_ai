import 'package:dio/dio.dart';
import 'package:kharcha_ai/core/config/api_config.dart';
import 'package:kharcha_ai/core/network/api_client.dart';
import 'package:kharcha_ai/core/network/api_exception.dart';
import 'package:kharcha_ai/models/analytics_model.dart';

class AnalyticsService {
  final ApiClient _apiClient;

  AnalyticsService({required ApiClient apiClient}) : _apiClient = apiClient;

  Future<SpendingAnalyticsModel> getSpendingAnalytics({int? month, int? year}) async {
    try {
      final query = <String, dynamic>{};
      if (month != null) query['month'] = month;
      if (year != null) query['year'] = year;

      final response = await _apiClient.dio.get(
        ApiConfig.spendingAnalyticsUrl,
        queryParameters: query,
      );
      return SpendingAnalyticsModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<List<SpendingInsightItemModel>> getInsights({int? month, int? year}) async {
    try {
      final query = <String, dynamic>{};
      if (month != null) query['month'] = month;
      if (year != null) query['year'] = year;

      final response = await _apiClient.dio.get(
        ApiConfig.spendingInsightsUrl,
        queryParameters: query,
      );
      final list = (response.data['insights'] as List<dynamic>?)
              ?.map((e) => SpendingInsightItemModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [];
      return list;
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }
}
