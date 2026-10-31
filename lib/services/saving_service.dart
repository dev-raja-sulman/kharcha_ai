import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import 'package:kharcha_ai/core/config/api_config.dart';
import 'package:kharcha_ai/core/network/api_client.dart';
import 'package:kharcha_ai/core/network/api_exception.dart';
import 'package:kharcha_ai/models/saving_goal_model.dart';

class SavingService {
  final ApiClient _apiClient;

  SavingService({required ApiClient apiClient}) : _apiClient = apiClient;

  /// Retrieve list of saving goals
  Future<SavingGoalListModel> getGoals({String? statusFilter}) async {
    try {
      final queryParams = <String, dynamic>{};
      if (statusFilter != null && statusFilter.isNotEmpty) {
        queryParams['status_filter'] = statusFilter;
      }

      final response = await _apiClient.dio.get(
        ApiConfig.savingGoalsUrl,
        queryParameters: queryParams,
      );

      return SavingGoalListModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Failed to fetch saving goals: ${e.toString()}');
    }
  }

  /// Get single goal by ID
  Future<SavingGoalModel> getGoalById(int id) async {
    try {
      final response = await _apiClient.dio.get('${ApiConfig.savingGoalsUrl}/$id');
      return SavingGoalModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Failed to fetch goal details: ${e.toString()}');
    }
  }

  /// Create a new saving goal
  Future<SavingGoalModel> createGoal({
    required String title,
    String? description,
    required double targetAmount,
    DateTime? startDate,
    required DateTime targetDate,
  }) async {
    try {
      final startStr = DateFormat('yyyy-MM-dd').format(startDate ?? DateTime.now());
      final targetStr = DateFormat('yyyy-MM-dd').format(targetDate);

      final response = await _apiClient.dio.post(
        ApiConfig.savingGoalsUrl,
        data: {
          'title': title.trim(),
          if (description != null && description.trim().isNotEmpty)
            'description': description.trim(),
          'target_amount': targetAmount.toStringAsFixed(2),
          'start_date': startStr,
          'target_date': targetStr,
        },
      );

      return SavingGoalModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Failed to create saving goal: ${e.toString()}');
    }
  }

  /// Update saving goal
  Future<SavingGoalModel> updateGoal(
    int id, {
    String? title,
    String? description,
    double? targetAmount,
    DateTime? targetDate,
    String? status,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (title != null) data['title'] = title.trim();
      if (description != null) data['description'] = description.trim();
      if (targetAmount != null) data['target_amount'] = targetAmount.toStringAsFixed(2);
      if (targetDate != null) {
        data['target_date'] = DateFormat('yyyy-MM-dd').format(targetDate);
      }
      if (status != null) data['status'] = status;

      final response = await _apiClient.dio.put(
        '${ApiConfig.savingGoalsUrl}/$id',
        data: data,
      );

      return SavingGoalModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Failed to update saving goal: ${e.toString()}');
    }
  }

  /// Delete saving goal
  Future<void> deleteGoal(int id) async {
    try {
      await _apiClient.dio.delete('${ApiConfig.savingGoalsUrl}/$id');
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Failed to delete saving goal: ${e.toString()}');
    }
  }

  /// Add a savings contribution
  Future<ContributionModel> addContribution(
    int goalId, {
    required double amount,
    DateTime? contributionDate,
    String? notes,
  }) async {
    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(contributionDate ?? DateTime.now());

      final response = await _apiClient.dio.post(
        '${ApiConfig.savingGoalsUrl}/$goalId/contributions',
        data: {
          'amount': amount.toStringAsFixed(2),
          'contribution_date': dateStr,
          if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
        },
      );

      return ContributionModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Failed to record contribution: ${e.toString()}');
    }
  }

  /// Get contribution history for a goal
  Future<List<ContributionModel>> getContributions(int goalId) async {
    try {
      final response = await _apiClient.dio.get('${ApiConfig.savingGoalsUrl}/$goalId/contributions');
      final list = response.data as List<dynamic>? ?? [];
      return list.map((e) => ContributionModel.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Failed to fetch contributions: ${e.toString()}');
    }
  }
}
