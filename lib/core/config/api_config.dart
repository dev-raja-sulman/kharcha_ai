import 'package:flutter/foundation.dart';

enum Environment { devEmulator, devPhysical, production }

class ApiConfig {
  // Override via command line: --dart-define=API_URL=http://192.168.1.13:8000
  static const String _customBaseUrl = String.fromEnvironment('API_URL', defaultValue: '');
  
  // Override environment mode: --dart-define=ENV=production
  static const String _envMode = String.fromEnvironment('ENV', defaultValue: 'dev');

  // Local development host constants
  static const String androidEmulatorHost = 'http://10.0.2.2:8000';
  static const String loopbackHost = 'http://127.0.0.1:8000';
  
  // Reachable local network IP for physical mobile device testing
  static const String physicalDeviceHost = 'http://192.168.1.13:8000';
  
  // Production URL (HTTPS)
  static const String productionHost = 'https://api.kharcha.ai';

  /// Resolves the active base URL dynamically based on environment, platform, and overrides
  static String get baseUrl {
    // 1. If explicit API_URL was provided via --dart-define, use it directly
    if (_customBaseUrl.isNotEmpty) {
      return _customBaseUrl;
    }

    // 2. Check production environment
    if (_envMode == 'production') {
      return productionHost;
    }

    // 3. Physical device override mode
    if (_envMode == 'physical') {
      return physicalDeviceHost;
    }

    // 4. Auto-detect platform for local development
    if (kIsWeb) {
      return loopbackHost;
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        // Android emulator maps 10.0.2.2 to the host development computer's 127.0.0.1
        return androidEmulatorHost;
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
        return loopbackHost;
      default:
        return loopbackHost;
    }
  }

  // API Endpoints
  static String get healthUrl => '$baseUrl/health';
  static String get registerUrl => '$baseUrl/api/v1/auth/register';
  static String get loginUrl => '$baseUrl/api/v1/auth/login';
  static String get meUrl => '$baseUrl/api/v1/auth/me';
  static String get expensesUrl => '$baseUrl/api/v1/expenses';
  static String get expenseSummaryUrl => '$baseUrl/api/v1/expenses/summary';
  static String get expenseCategoriesUrl => '$baseUrl/api/v1/expenses/categories';
  static String get receiptScanUrl => '$baseUrl/api/v1/receipts/scan';
  static String get budgetsUrl => '$baseUrl/api/v1/budgets';
  static String get budgetProgressUrl => '$baseUrl/api/v1/budgets/progress';
  static String get spendingAnalyticsUrl => '$baseUrl/api/v1/analytics/spending';
  static String get spendingInsightsUrl => '$baseUrl/api/v1/analytics/insights';
  static String get recurringExpensesUrl => '$baseUrl/api/v1/recurring-expenses';
  static String get recurringProcessUrl => '$baseUrl/api/v1/recurring-expenses/process';
  static String get reportsUrl => '$baseUrl/api/v1/reports';
  static String get reportsCsvExportUrl => '$baseUrl/api/v1/reports/export/csv';
  static String get reportsPdfExportUrl => '$baseUrl/api/v1/reports/export/pdf';

  // Phase 6 Endpoints
  static String get incomesUrl => '$baseUrl/api/v1/incomes';
  static String get incomeSummaryUrl => '$baseUrl/api/v1/incomes/summary';
  static String get incomeSourcesUrl => '$baseUrl/api/v1/income-sources';
  static String get cashflowUrl => '$baseUrl/api/v1/analytics/cashflow';
  static String get savingGoalsUrl => '$baseUrl/api/v1/saving-goals';
  static String get billsUrl => '$baseUrl/api/v1/bills';
  static String get billsUpcomingUrl => '$baseUrl/api/v1/bills/upcoming';
  static String get billsSummaryUrl => '$baseUrl/api/v1/bills/summary';
  static String get advisorOverviewUrl => '$baseUrl/api/v1/financial-advisor/overview';
  static String get advisorInsightsUrl => '$baseUrl/api/v1/financial-advisor/insights';
  static String get advisorChatUrl => '$baseUrl/api/v1/financial-advisor/chat';


  // Network Timeout Configurations
  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 10);
  static const Duration sendTimeout = Duration(seconds: 10);
}
