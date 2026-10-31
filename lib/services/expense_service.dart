import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import 'package:kharcha_ai/core/config/api_config.dart';
import 'package:kharcha_ai/core/network/api_client.dart';
import 'package:kharcha_ai/core/network/api_exception.dart';
import 'package:kharcha_ai/models/expense_model.dart';
import 'package:kharcha_ai/models/expense_summary.dart';

class ExpenseService {
  final ApiClient _apiClient;

  ExpenseService({required ApiClient apiClient}) : _apiClient = apiClient;

  /// Create a new expense item on FastAPI backend
  Future<ExpenseModel> createExpense({
    required String title,
    required double amount,
    required String category,
    String? currency,
    String? description,
    DateTime? expenseDate,
    String? paymentMethod,
  }) async {
    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(expenseDate ?? DateTime.now());
      final response = await _apiClient.dio.post(
        ApiConfig.expensesUrl,
        data: {
          'title': title.trim(),
          'amount': amount.toStringAsFixed(2),
          'category': category.trim(),
          'currency': currency ?? 'PKR',
          if (description != null && description.trim().isNotEmpty)
            'description': description.trim(),
          'expense_date': dateStr,
          'payment_method': paymentMethod ?? 'Cash',
        },
      );

      return ExpenseModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Failed to record expense: ${e.toString()}');
    }
  }

  /// Retrieve list of expenses with optional filtering
  Future<List<ExpenseModel>> getExpenses({
    String? category,
    DateTime? startDate,
    DateTime? endDate,
    String? search,
    int skip = 0,
    int limit = 50,
    String sortBy = 'date_desc',
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'skip': skip,
        'limit': limit,
        'sort_by': sortBy,
      };

      if (category != null && category.isNotEmpty && category != 'All') {
        queryParams['category'] = category;
      }
      if (startDate != null) {
        queryParams['start_date'] = DateFormat('yyyy-MM-dd').format(startDate);
      }
      if (endDate != null) {
        queryParams['end_date'] = DateFormat('yyyy-MM-dd').format(endDate);
      }
      if (search != null && search.trim().isNotEmpty) {
        queryParams['search'] = search.trim();
      }

      final response = await _apiClient.dio.get(
        ApiConfig.expensesUrl,
        queryParameters: queryParams,
      );

      final data = response.data as Map<String, dynamic>;
      final items = (data['items'] as List<dynamic>?)
              ?.map((item) => ExpenseModel.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [];

      return items;
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Failed to load expenses: ${e.toString()}');
    }
  }

  /// Retrieve single expense by ID
  Future<ExpenseModel> getExpenseById(int id) async {
    try {
      final response = await _apiClient.dio.get('${ApiConfig.expensesUrl}/$id');
      return ExpenseModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// Update an existing expense
  Future<ExpenseModel> updateExpense(
    int id, {
    String? title,
    double? amount,
    String? category,
    String? currency,
    String? description,
    DateTime? expenseDate,
    String? paymentMethod,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (title != null) data['title'] = title.trim();
      if (amount != null) data['amount'] = amount.toStringAsFixed(2);
      if (category != null) data['category'] = category.trim();
      if (currency != null) data['currency'] = currency.trim();
      if (description != null) data['description'] = description.trim();
      if (expenseDate != null) {
        data['expense_date'] = DateFormat('yyyy-MM-dd').format(expenseDate);
      }
      if (paymentMethod != null) data['payment_method'] = paymentMethod;

      final response = await _apiClient.dio.patch(
        '${ApiConfig.expensesUrl}/$id',
        data: data,
      );

      return ExpenseModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// Delete an expense
  Future<void> deleteExpense(int id) async {
    try {
      await _apiClient.dio.delete('${ApiConfig.expensesUrl}/$id');
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// Retrieve aggregated summary
  Future<ExpenseSummaryModel> getSummary({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (startDate != null) {
        queryParams['start_date'] = DateFormat('yyyy-MM-dd').format(startDate);
      }
      if (endDate != null) {
        queryParams['end_date'] = DateFormat('yyyy-MM-dd').format(endDate);
      }

      final response = await _apiClient.dio.get(
        ApiConfig.expenseSummaryUrl,
        queryParameters: queryParams,
      );

      return ExpenseSummaryModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// Retrieve standard categories
  Future<List<String>> getCategories() async {
    try {
      final response = await _apiClient.dio.get(ApiConfig.expenseCategoriesUrl);
      return (response.data as List<dynamic>).map((e) => e.toString()).toList();
    } catch (_) {
      // Standard fallback list
      return [
        'Food',
        'Transport',
        'Shopping',
        'Bills',
        'Healthcare',
        'Education',
        'Entertainment',
        'Rent',
        'Travel',
        'Other'
      ];
    }
  }
}
