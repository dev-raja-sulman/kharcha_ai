import 'package:flutter/material.dart';
import 'package:kharcha_ai/core/constants/app_colors.dart';
import 'package:kharcha_ai/models/user_model.dart';
import 'package:kharcha_ai/screens/analytics_screen.dart';
import 'package:kharcha_ai/screens/dashboard_screen.dart';
import 'package:kharcha_ai/screens/financial_advisor_screen.dart';
import 'package:kharcha_ai/screens/profile_screen.dart';
import 'package:kharcha_ai/screens/transactions_hub_screen.dart';
import 'package:kharcha_ai/services/analytics_service.dart';
import 'package:kharcha_ai/services/auth_service.dart';
import 'package:kharcha_ai/services/expense_service.dart';
import 'package:kharcha_ai/services/financial_advisor_service.dart';
import 'package:kharcha_ai/services/income_service.dart';

class MainNavigationScreen extends StatefulWidget {
  final AuthService authService;
  final UserModel? initialUser;
  final int initialIndex;

  const MainNavigationScreen({
    super.key,
    required this.authService,
    this.initialUser,
    this.initialIndex = 0,
  });

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  late int _currentIndex;
  late UserModel? _currentUser;

  late final ExpenseService _expenseService;
  late final IncomeService _incomeService;
  late final AnalyticsService _analyticsService;
  late final FinancialAdvisorService _advisorService;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _currentUser = widget.initialUser;

    _expenseService = ExpenseService(apiClient: widget.authService.apiClient);
    _incomeService = IncomeService(apiClient: widget.authService.apiClient);
    _analyticsService = AnalyticsService(apiClient: widget.authService.apiClient);
    _advisorService = FinancialAdvisorService(apiClient: widget.authService.apiClient);
  }

  void switchTab(int index) {
    if (mounted) {
      setState(() {
        _currentIndex = index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final pages = [
      DashboardScreen(
        authService: widget.authService,
        expenseService: _expenseService,
        initialUser: _currentUser,
        onNavigateTab: switchTab,
      ),
      TransactionsHubScreen(
        expenseService: _expenseService,
        incomeService: _incomeService,
        currentUser: _currentUser,
      ),
      AnalyticsScreen(
        analyticsService: _analyticsService,
      ),
      FinancialAdvisorScreen(
        advisorService: _advisorService,
      ),
      ProfileScreen(
        authService: widget.authService,
        initialUser: _currentUser,
      ),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: pages,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          border: Border(
            top: BorderSide(
              color: isDark ? AppColors.darkCardBorder : AppColors.cardBorder,
              width: 1,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          type: BottomNavigationBarType.fixed,
          backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
          selectedFontSize: 11,
          unselectedFontSize: 11,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500),
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.swap_horiz_rounded),
              activeIcon: Icon(Icons.swap_horizontal_circle_rounded),
              label: 'Transactions',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.pie_chart_outline_rounded),
              activeIcon: Icon(Icons.pie_chart_rounded),
              label: 'Analytics',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.auto_awesome_outlined),
              activeIcon: Icon(Icons.auto_awesome_rounded),
              label: 'AI Advisor',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline_rounded),
              activeIcon: Icon(Icons.person_rounded),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
