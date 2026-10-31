import 'package:dio/dio.dart';
import 'package:kharcha_ai/core/config/api_config.dart';
import 'package:kharcha_ai/core/network/api_client.dart';
import 'package:kharcha_ai/core/network/api_exception.dart';
import 'package:kharcha_ai/models/financial_advisor_model.dart';

class FinancialAdvisorService {
  final ApiClient _apiClient;

  FinancialAdvisorService({required ApiClient apiClient}) : _apiClient = apiClient;

  /// Fetch financial overview metrics & health score
  Future<AdvisorOverviewModel> getOverview() async {
    try {
      final response = await _apiClient.dio.get(ApiConfig.advisorOverviewUrl);
      return AdvisorOverviewModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Failed to fetch advisor overview: ${e.toString()}');
    }
  }

  /// Fetch structured AI insights, strengths, and recommendations
  Future<AdvisorInsightsModel> getInsights() async {
    try {
      final response = await _apiClient.dio.get(ApiConfig.advisorInsightsUrl);
      return AdvisorInsightsModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Failed to fetch advisor insights: ${e.toString()}');
    }
  }

  /// Chat with the AI Financial Advisor grounded in user metrics
  Future<AdvisorChatResponseModel> sendMessage(String message) async {
    try {
      final response = await _apiClient.dio.post(
        ApiConfig.advisorChatUrl,
        data: {'message': message},
      );
      return AdvisorChatResponseModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Advisor chat failed: ${e.toString()}');
    }
  }
}
