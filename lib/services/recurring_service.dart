import 'package:dio/dio.dart';
import 'package:kharcha_ai/core/config/api_config.dart';
import 'package:kharcha_ai/core/network/api_client.dart';
import 'package:kharcha_ai/core/network/api_exception.dart';
import 'package:kharcha_ai/models/expense_model.dart';
import 'package:kharcha_ai/models/recurring_expense_model.dart';

class RecurringService {
  final ApiClient _apiClient;

  RecurringService({required ApiClient apiClient}) : _apiClient = apiClient;

  Future<List<RecurringExpenseModel>> getRecurringRules({String? status}) async {
    try {
      final query = <String, dynamic>{};
      if (status != null && status.isNotEmpty && status != 'all') {
        query['status'] = status.toLowerCase();
      }

      final response = await _apiClient.dio.get(
        ApiConfig.recurringExpensesUrl,
        queryParameters: query,
      );

      final items = (response.data['items'] as List<dynamic>?)
              ?.map((e) => RecurringExpenseModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [];
      return items;
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<RecurringExpenseModel> createRecurringRule({
    required String title,
    required double amount,
    required String category,
    String? description,
    required String frequency,
    String? paymentMethod,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final response = await _apiClient.dio.post(
        ApiConfig.recurringExpensesUrl,
        data: {
          'title': title.trim(),
          'amount': amount.toStringAsFixed(2),
          'category': category.trim(),
          'description': description?.trim(),
          'frequency': frequency.toLowerCase(),
          'payment_method': paymentMethod ?? 'Cash',
          'start_date': (startDate ?? DateTime.now()).toIso8601String().split('T')[0],
          if (endDate != null) 'end_date': endDate.toIso8601String().split('T')[0],
        },
      );
      return RecurringExpenseModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<RecurringExpenseModel> updateRecurringRule({
    required int id,
    String? title,
    double? amount,
    String? category,
    String? description,
    String? frequency,
    String? paymentMethod,
    DateTime? endDate,
  }) async {
    try {
      final payload = <String, dynamic>{};
      if (title != null) payload['title'] = title.trim();
      if (amount != null) payload['amount'] = amount.toStringAsFixed(2);
      if (category != null) payload['category'] = category.trim();
      if (description != null) payload['description'] = description.trim();
      if (frequency != null) payload['frequency'] = frequency.toLowerCase();
      if (paymentMethod != null) payload['payment_method'] = paymentMethod;
      if (endDate != null) payload['end_date'] = endDate.toIso8601String().split('T')[0];

      final response = await _apiClient.dio.put(
        '${ApiConfig.recurringExpensesUrl}/$id',
        data: payload,
      );
      return RecurringExpenseModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<RecurringExpenseModel> pauseRule(int id) async {
    try {
      final response = await _apiClient.dio.post('${ApiConfig.recurringExpensesUrl}/$id/pause');
      return RecurringExpenseModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<RecurringExpenseModel> resumeRule(int id) async {
    try {
      final response = await _apiClient.dio.post('${ApiConfig.recurringExpensesUrl}/$id/resume');
      return RecurringExpenseModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<RecurringExpenseModel> cancelRule(int id) async {
    try {
      final response = await _apiClient.dio.post('${ApiConfig.recurringExpensesUrl}/$id/cancel');
      return RecurringExpenseModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<List<ExpenseModel>> getRuleHistory(int id) async {
    try {
      final response = await _apiClient.dio.get('${ApiConfig.recurringExpensesUrl}/$id/history');
      final list = (response.data as List<dynamic>?)
              ?.map((e) => ExpenseModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [];
      return list;
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<Map<String, dynamic>> processDueExpenses() async {
    try {
      final response = await _apiClient.dio.post(ApiConfig.recurringProcessUrl);
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }
}
