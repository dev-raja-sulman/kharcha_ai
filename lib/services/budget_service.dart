import 'package:dio/dio.dart';
import 'package:kharcha_ai/core/config/api_config.dart';
import 'package:kharcha_ai/core/network/api_client.dart';
import 'package:kharcha_ai/core/network/api_exception.dart';
import 'package:kharcha_ai/models/budget_model.dart';

class BudgetService {
  final ApiClient _apiClient;

  BudgetService({required ApiClient apiClient}) : _apiClient = apiClient;

  Future<BudgetModel> createBudget({
    required String name,
    required double amount,
    String? category,
    required int month,
    required int year,
  }) async {
    try {
      final response = await _apiClient.dio.post(
        ApiConfig.budgetsUrl,
        data: {
          'name': name.trim(),
          'amount': amount.toStringAsFixed(2),
          'category': (category != null && category.trim().isNotEmpty && category != 'All')
              ? category.trim()
              : null,
          'month': month,
          'year': year,
        },
      );
      return BudgetModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<List<BudgetModel>> getBudgets({int? month, int? year}) async {
    try {
      final query = <String, dynamic>{};
      if (month != null) query['month'] = month;
      if (year != null) query['year'] = year;

      final response = await _apiClient.dio.get(
        ApiConfig.budgetsUrl,
        queryParameters: query,
      );

      final items = (response.data['items'] as List<dynamic>?)
              ?.map((e) => BudgetModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [];
      return items;
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<void> deleteBudget(int id) async {
    try {
      await _apiClient.dio.delete('${ApiConfig.budgetsUrl}/$id');
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }
}
