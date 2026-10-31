import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import 'package:kharcha_ai/core/config/api_config.dart';
import 'package:kharcha_ai/core/network/api_client.dart';
import 'package:kharcha_ai/core/network/api_exception.dart';
import 'package:kharcha_ai/models/bill_model.dart';

class BillService {
  final ApiClient _apiClient;

  BillService({required ApiClient apiClient}) : _apiClient = apiClient;

  /// Retrieve list of bills with optional status and category filters
  Future<BillListModel> getBills({String? status, String? category}) async {
    try {
      final queryParams = <String, dynamic>{};
      if (status != null && status.isNotEmpty) {
        queryParams['status'] = status;
      }
      if (category != null && category.isNotEmpty) {
        queryParams['category'] = category;
      }

      final response = await _apiClient.dio.get(
        ApiConfig.billsUrl,
        queryParameters: queryParams,
      );

      return BillListModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Failed to fetch bills: ${e.toString()}');
    }
  }

  /// Get summary metrics for bills
  Future<BillSummaryModel> getBillSummary() async {
    try {
      final response = await _apiClient.dio.get(ApiConfig.billsSummaryUrl);
      return BillSummaryModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Failed to fetch bill summary: ${e.toString()}');
    }
  }

  /// Get upcoming bills due within N days
  Future<List<BillModel>> getUpcomingBills({int days = 14}) async {
    try {
      final response = await _apiClient.dio.get(
        ApiConfig.billsUpcomingUrl,
        queryParameters: {'days': days},
      );

      final list = (response.data as List<dynamic>?) ?? [];
      return list.map((item) => BillModel.fromJson(item as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Failed to fetch upcoming bills: ${e.toString()}');
    }
  }

  /// Get a single bill by ID
  Future<BillModel> getBillById(int id) async {
    try {
      final response = await _apiClient.dio.get('${ApiConfig.billsUrl}/$id');
      return BillModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Failed to fetch bill details: ${e.toString()}');
    }
  }

  /// Create a new bill
  Future<BillModel> createBill({
    required String title,
    required String category,
    required double amount,
    required DateTime dueDate,
    String frequency = 'one_time',
    bool reminderEnabled = true,
  }) async {
    try {
      final dueDateStr = DateFormat('yyyy-MM-dd').format(dueDate);

      final response = await _apiClient.dio.post(
        ApiConfig.billsUrl,
        data: {
          'title': title,
          'category': category,
          'amount': amount.toStringAsFixed(2),
          'due_date': dueDateStr,
          'frequency': frequency,
          'reminder_enabled': reminderEnabled,
        },
      );

      return BillModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Failed to create bill: ${e.toString()}');
    }
  }

  /// Update an existing bill
  Future<BillModel> updateBill({
    required int id,
    String? title,
    String? category,
    double? amount,
    DateTime? dueDate,
    String? frequency,
    bool? reminderEnabled,
    String? status,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (title != null) data['title'] = title;
      if (category != null) data['category'] = category;
      if (amount != null) data['amount'] = amount.toStringAsFixed(2);
      if (dueDate != null) data['due_date'] = DateFormat('yyyy-MM-dd').format(dueDate);
      if (frequency != null) data['frequency'] = frequency;
      if (reminderEnabled != null) data['reminder_enabled'] = reminderEnabled;
      if (status != null) data['status'] = status;

      final response = await _apiClient.dio.put(
        '${ApiConfig.billsUrl}/$id',
        data: data,
      );

      return BillModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Failed to update bill: ${e.toString()}');
    }
  }

  /// Delete a bill
  Future<void> deleteBill(int id) async {
    try {
      await _apiClient.dio.delete('${ApiConfig.billsUrl}/$id');
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Failed to delete bill: ${e.toString()}');
    }
  }

  /// Mark a bill as paid with optional expense record synchronization
  Future<BillModel> markAsPaid({
    required int id,
    DateTime? paidDate,
    bool createExpense = true,
    String paymentMethod = 'Bank Transfer',
  }) async {
    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(paidDate ?? DateTime.now());

      final response = await _apiClient.dio.post(
        '${ApiConfig.billsUrl}/$id/mark-paid',
        data: {
          'paid_date': dateStr,
          'create_expense': createExpense,
          'payment_method': paymentMethod,
        },
      );

      return BillModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Failed to mark bill as paid: ${e.toString()}');
    }
  }
}
