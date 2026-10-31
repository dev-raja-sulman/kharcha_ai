import 'package:flutter/material.dart';
import 'package:kharcha_ai/core/currency/currency_controller.dart';
import 'package:kharcha_ai/core/network/api_client.dart';
import 'package:kharcha_ai/core/storage/secure_storage_service.dart';
import 'package:kharcha_ai/core/theme/app_theme.dart';
import 'package:kharcha_ai/core/theme/theme_controller.dart';
import 'package:kharcha_ai/screens/splash_screen.dart';
import 'package:kharcha_ai/services/auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await ThemeController.instance.init();
  await CurrencyController.instance.init();

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
    return AnimatedBuilder(
      animation: Listenable.merge([
        ThemeController.instance,
        CurrencyController.instance,
      ]),
      builder: (context, _) {
        return MaterialApp(
          title: 'KharchaAI',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: ThemeController.instance.themeMode,
          home: SplashScreen(authService: authService),
        );
      },
    );
  }
}
