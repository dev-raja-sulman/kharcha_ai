import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import 'package:kharcha_ai/core/config/api_config.dart';
import 'package:kharcha_ai/core/network/api_client.dart';
import 'package:kharcha_ai/core/network/api_exception.dart';
import 'package:kharcha_ai/models/income_model.dart';

class IncomeService {
  final ApiClient _apiClient;

  IncomeService({required ApiClient apiClient}) : _apiClient = apiClient;

  /// Retrieve available active income sources (Salary, Freelance, etc.)
  Future<List<IncomeSourceModel>> getIncomeSources() async {
    try {
      final response = await _apiClient.dio.get(ApiConfig.incomeSourcesUrl);
      final list = response.data as List<dynamic>? ?? [];
      return list.map((e) => IncomeSourceModel.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Failed to fetch income sources: ${e.toString()}');
    }
  }

  /// Create a custom income source
  Future<IncomeSourceModel> createIncomeSource({
    required String name,
    String? description,
  }) async {
    try {
      final response = await _apiClient.dio.post(
        ApiConfig.incomeSourcesUrl,
        data: {
          'name': name.trim(),
          if (description != null && description.trim().isNotEmpty)
            'description': description.trim(),
          'is_active': true,
        },
      );
      return IncomeSourceModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Failed to create income source: ${e.toString()}');
    }
  }

  /// Create a new income transaction
  Future<IncomeModel> createIncome({
    required String title,
    required double amount,
    String currency = 'PKR',
    DateTime? incomeDate,
    String paymentMethod = 'Bank Transfer',
    String? description,
    int? sourceId,
  }) async {
    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(incomeDate ?? DateTime.now());
      final response = await _apiClient.dio.post(
        ApiConfig.incomesUrl,
        data: {
          'title': title.trim(),
          'amount': amount.toStringAsFixed(2),
          'currency': currency,
          'income_date': dateStr,
          'payment_method': paymentMethod,
          if (description != null && description.trim().isNotEmpty)
            'description': description.trim(),
          if (sourceId != null) 'source_id': sourceId,
        },
      );
      return IncomeModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Failed to record income: ${e.toString()}');
    }
  }

  /// Retrieve paginated list of incomes with optional filtering
  Future<IncomeListModel> getIncomes({
    DateTime? startDate,
    DateTime? endDate,
    int? sourceId,
    String? search,
    int page = 1,
    int pageSize = 50,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'page': page,
        'page_size': pageSize,
      };

      if (startDate != null) {
        queryParams['start_date'] = DateFormat('yyyy-MM-dd').format(startDate);
      }
      if (endDate != null) {
        queryParams['end_date'] = DateFormat('yyyy-MM-dd').format(endDate);
      }
      if (sourceId != null) {
        queryParams['source_id'] = sourceId;
      }
      if (search != null && search.trim().isNotEmpty) {
        queryParams['search'] = search.trim();
      }

      final response = await _apiClient.dio.get(
        ApiConfig.incomesUrl,
        queryParameters: queryParams,
      );

      return IncomeListModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Failed to fetch incomes: ${e.toString()}');
    }
  }

  /// Get income by ID
  Future<IncomeModel> getIncomeById(int id) async {
    try {
      final response = await _apiClient.dio.get('${ApiConfig.incomesUrl}/$id');
      return IncomeModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Failed to fetch income details: ${e.toString()}');
    }
  }

  /// Update an existing income transaction
  Future<IncomeModel> updateIncome(
    int id, {
    String? title,
    double? amount,
    String? currency,
    DateTime? incomeDate,
    String? paymentMethod,
    String? description,
    int? sourceId,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (title != null) data['title'] = title.trim();
      if (amount != null) data['amount'] = amount.toStringAsFixed(2);
      if (currency != null) data['currency'] = currency;
      if (incomeDate != null) {
        data['income_date'] = DateFormat('yyyy-MM-dd').format(incomeDate);
      }
      if (paymentMethod != null) data['payment_method'] = paymentMethod;
      if (description != null) data['description'] = description.trim();
      if (sourceId != null) data['source_id'] = sourceId;

      final response = await _apiClient.dio.put(
        '${ApiConfig.incomesUrl}/$id',
        data: data,
      );
      return IncomeModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Failed to update income: ${e.toString()}');
    }
  }

  /// Delete an income transaction
  Future<void> deleteIncome(int id) async {
    try {
      await _apiClient.dio.delete('${ApiConfig.incomesUrl}/$id');
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Failed to delete income: ${e.toString()}');
    }
  }

  /// Retrieve aggregated income summary (source breakdown, monthly totals)
  Future<IncomeSummaryModel> getIncomeSummary({int? month, int? year}) async {
    try {
      final queryParams = <String, dynamic>{};
      if (month != null) queryParams['month'] = month;
      if (year != null) queryParams['year'] = year;

      final response = await _apiClient.dio.get(
        ApiConfig.incomeSummaryUrl,
        queryParameters: queryParams,
      );

      return IncomeSummaryModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Failed to fetch income summary: ${e.toString()}');
    }
  }
}
