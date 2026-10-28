import 'package:flutter/material.dart';
import 'package:kharcha_ai/core/constants/app_colors.dart';
import 'package:kharcha_ai/core/network/api_client.dart';
import 'package:kharcha_ai/core/storage/secure_storage_service.dart';
import 'package:kharcha_ai/screens/splash_screen.dart';
import 'package:kharcha_ai/services/auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final storage = SecureStorageService();
  final apiClient = ApiClient(storage: storage);
  final authService = AuthService(apiClient: apiClient, storage: storage);

  runApp(KharchaAIApp(authService: authService));
}

class KharchaAIApp extends StatelessWidget {
  final AuthService authService;

  const KharchaAIApp({
    super.key,
    required this.authService,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KharchaAI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          primary: AppColors.primary,
          surface: AppColors.surface,
        ),
        scaffoldBackgroundColor: AppColors.background,
        fontFamily: 'Inter',
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
        ),
      ),
      home: SplashScreen(authService: authService),
    );
  }
}
