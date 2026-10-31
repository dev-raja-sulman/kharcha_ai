import 'package:dio/dio.dart';
import 'package:kharcha_ai/core/network/api_client.dart';
import 'package:kharcha_ai/core/network/api_exception.dart';
import 'package:kharcha_ai/models/user_model.dart';

class CurrencyService {
  final ApiClient apiClient;

  CurrencyService({required this.apiClient});

  Future<List<Map<String, dynamic>>> getSupportedCurrencies() async {
    try {
      final response = await apiClient.dio.get('/api/v1/currencies');
      final data = response.data as Map<String, dynamic>;
      final list = data['currencies'] as List<dynamic>? ?? [];
      return list.map((c) => c as Map<String, dynamic>).toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<UserModel> updatePreferredCurrency(String currency) async {
    try {
      final response = await apiClient.dio.put(
        '/api/v1/auth/currency',
        data: {'currency': currency.toUpperCase().trim()},
      );
      return UserModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}
