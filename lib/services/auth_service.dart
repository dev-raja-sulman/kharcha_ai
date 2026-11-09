import 'package:dio/dio.dart';
import 'package:kharcha_ai/core/config/api_config.dart';
import 'package:kharcha_ai/core/network/api_client.dart';
import 'package:kharcha_ai/core/network/api_exception.dart';
import 'package:kharcha_ai/core/storage/secure_storage_service.dart';
import 'package:kharcha_ai/models/auth_response.dart';
import 'package:kharcha_ai/models/user_model.dart';

class AuthService {
  final ApiClient _apiClient;
  final SecureStorageService _storage;

  AuthService({
    required ApiClient apiClient,
    required SecureStorageService storage,
  })  : _apiClient = apiClient,
        _storage = storage;

  ApiClient get apiClient => _apiClient;

  /// Register a new account on KharchaAI backend
  Future<UserModel> register({
    required String email,
    required String password,
    String? fullName,
  }) async {
    try {
      final response = await _apiClient.dio.post(
        ApiConfig.registerUrl,
        data: {
          'email': email.trim().toLowerCase(),
          'password': password,
          if (fullName != null && fullName.trim().isNotEmpty)
            'full_name': fullName.trim(),
        },
      );

      final authResponse = AuthResponse.fromJson(response.data as Map<String, dynamic>);
      // Store JWT token securely
      await _storage.saveToken(authResponse.accessToken);
      return authResponse.user;
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Registration failed: ${e.toString()}');
    }
  }

  /// Verify email with 6-digit OTP code sent during registration
  Future<UserModel> verifyEmail({
    required String email,
    required String otp,
  }) async {
    try {
      final response = await _apiClient.dio.post(
        ApiConfig.verifyEmailUrl,
        data: {
          'email': email.trim().toLowerCase(),
          'otp': otp.trim(),
        },
      );

      final authResponse = AuthResponse.fromJson(response.data as Map<String, dynamic>);
      await _storage.saveToken(authResponse.accessToken);
      return authResponse.user;
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Email verification failed: ${e.toString()}');
    }
  }

  /// Resend a 6-digit OTP verification code (supports registration or password_reset)
  Future<Map<String, dynamic>> resendOtp({
    required String email,
    String purpose = 'registration',
  }) async {
    try {
      final response = await _apiClient.dio.post(
        ApiConfig.resendOtpUrl,
        data: {
          'email': email.trim().toLowerCase(),
          'purpose': purpose,
        },
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Could not resend verification code: ${e.toString()}');
    }
  }

  /// Authenticate an existing account on KharchaAI backend
  Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _apiClient.dio.post(
        ApiConfig.loginUrl,
        data: {
          'email': email.trim().toLowerCase(),
          'password': password,
        },
      );

      final authResponse = AuthResponse.fromJson(response.data as Map<String, dynamic>);
      // Store JWT token securely
      await _storage.saveToken(authResponse.accessToken);
      return authResponse.user;
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Login failed: ${e.toString()}');
    }
  }

  /// Retrieve the profile of the current authenticated user
  Future<UserModel> getProfile() async {
    try {
      final response = await _apiClient.dio.get(ApiConfig.meUrl);
      return UserModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Could not fetch user profile: ${e.toString()}');
    }
  }

  /// Update user profile details (full name and/or preferred currency)
  Future<UserModel> updateProfile({
    String? fullName,
    String? preferredCurrency,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (fullName != null) data['full_name'] = fullName.trim();
      if (preferredCurrency != null) {
        data['preferred_currency'] = preferredCurrency.trim().toUpperCase();
      }

      final response = await _apiClient.dio.patch(
        ApiConfig.meUrl,
        data: data,
      );
      return UserModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Could not update profile: ${e.toString()}');
    }
  }

  /// Update preferred display currency
  Future<UserModel> updatePreferredCurrency(String currency) async {
    try {
      final response = await _apiClient.dio.put(
        ApiConfig.currencyUrl,
        data: {'currency': currency.trim().toUpperCase()},
      );
      return UserModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Could not update preferred currency: ${e.toString()}');
    }
  }

  /// End the user session and clear stored credentials
  Future<void> logout() async {
    await _storage.clearAll();
  }

  /// Check whether an authenticated session exists locally
  Future<bool> isLoggedIn() async {
    return await _storage.hasToken();
  }

  SecureStorageService get storage => _storage;

  /// Request 6-digit OTP for password reset
  Future<Map<String, dynamic>> forgotPassword(String email) async {
    try {
      final response = await _apiClient.dio.post(
        ApiConfig.forgotPasswordUrl,
        data: {'email': email.trim().toLowerCase()},
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Forgot password request failed: ${e.toString()}');
    }
  }

  /// Verify 6-digit OTP
  Future<bool> verifyOtp({required String email, required String otp}) async {
    try {
      final response = await _apiClient.dio.post(
        ApiConfig.verifyOtpUrl,
        data: {
          'email': email.trim().toLowerCase(),
          'otp': otp.trim(),
        },
      );
      final data = response.data as Map<String, dynamic>;
      return data['valid'] == true;
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'OTP verification failed: ${e.toString()}');
    }
  }

  /// Reset password using verified OTP
  Future<UserModel> resetPassword({
    required String email,
    required String otp,
    required String newPassword,
  }) async {
    try {
      final response = await _apiClient.dio.post(
        ApiConfig.resetPasswordUrl,
        data: {
          'email': email.trim().toLowerCase(),
          'otp': otp.trim(),
          'new_password': newPassword,
        },
      );
      final authResponse = AuthResponse.fromJson(response.data as Map<String, dynamic>);
      await _storage.saveToken(authResponse.accessToken);
      return authResponse.user;
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Password reset failed: ${e.toString()}');
    }
  }

  /// Social Login via Google or Apple
  Future<UserModel> socialLogin({
    required String provider,
    required String email,
    String? name,
    String? token,
  }) async {
    try {
      final response = await _apiClient.dio.post(
        ApiConfig.socialLoginUrl,
        data: {
          'provider': provider,
          'email': email.trim().toLowerCase(),
          if (name != null) 'name': name.trim(),
          if (token != null) 'token': token,
        },
      );
      final authResponse = AuthResponse.fromJson(response.data as Map<String, dynamic>);
      await _storage.saveToken(authResponse.accessToken);
      return authResponse.user;
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: '$provider sign-in failed: ${e.toString()}');
    }
  }

  /// Check backend health status
  Future<Map<String, dynamic>> checkHealth() async {
    try {
      final response = await _apiClient.dio.get(ApiConfig.healthUrl);
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }
}
