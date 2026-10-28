import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:kharcha_ai/core/config/api_config.dart';
import 'package:kharcha_ai/core/network/api_client.dart';
import 'package:kharcha_ai/core/network/api_exception.dart';
import 'package:kharcha_ai/models/report_model.dart';

class ReportService {
  final ApiClient _apiClient;

  ReportService({required ApiClient apiClient}) : _apiClient = apiClient;

  Future<AdvancedReportModel> getAdvancedReport({
    String reportType = 'monthly',
    DateTime? startDate,
    DateTime? endDate,
    int? year,
    int? month,
    String? category,
  }) async {
    try {
      final query = <String, dynamic>{
        'report_type': reportType.toLowerCase(),
      };
      if (startDate != null) {
        query['start_date'] = startDate.toIso8601String().split('T')[0];
      }
      if (endDate != null) {
        query['end_date'] = endDate.toIso8601String().split('T')[0];
      }
      if (year != null) query['year'] = year;
      if (month != null) query['month'] = month;
      if (category != null && category.isNotEmpty && category != 'All') {
        query['category'] = category;
      }

      final response = await _apiClient.dio.get(
        ApiConfig.reportsUrl,
        queryParameters: query,
      );

      return AdvancedReportModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<String> downloadCsvReport({
    String reportType = 'monthly',
    DateTime? startDate,
    DateTime? endDate,
    int? year,
    int? month,
    String? category,
  }) async {
    try {
      final query = <String, dynamic>{
        'report_type': reportType.toLowerCase(),
      };
      if (startDate != null) {
        query['start_date'] = startDate.toIso8601String().split('T')[0];
      }
      if (endDate != null) {
        query['end_date'] = endDate.toIso8601String().split('T')[0];
      }
      if (year != null) query['year'] = year;
      if (month != null) query['month'] = month;
      if (category != null && category.isNotEmpty && category != 'All') {
        query['category'] = category;
      }

      final response = await _apiClient.dio.get(
        ApiConfig.reportsCsvExportUrl,
        queryParameters: query,
        options: Options(responseType: ResponseType.plain),
      );

      return response.data.toString();
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<Uint8List> downloadPdfReport({
    String reportType = 'monthly',
    DateTime? startDate,
    DateTime? endDate,
    int? year,
    int? month,
    String? category,
  }) async {
    try {
      final query = <String, dynamic>{
        'report_type': reportType.toLowerCase(),
      };
      if (startDate != null) {
        query['start_date'] = startDate.toIso8601String().split('T')[0];
      }
      if (endDate != null) {
        query['end_date'] = endDate.toIso8601String().split('T')[0];
      }
      if (year != null) query['year'] = year;
      if (month != null) query['month'] = month;
      if (category != null && category.isNotEmpty && category != 'All') {
        query['category'] = category;
      }

      final response = await _apiClient.dio.get(
        ApiConfig.reportsPdfExportUrl,
        queryParameters: query,
        options: Options(responseType: ResponseType.bytes),
      );

      return Uint8List.fromList(response.data as List<int>);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }
}
