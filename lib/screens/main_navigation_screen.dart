import 'package:flutter/material.dart';
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
    // 5 tabs matching Screenshot 3:
    // 0: Home, 1: Activity, 2: Advisor, 3: Insights, 4: Settings
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
      FinancialAdvisorScreen(
        advisorService: _advisorService,
        preferredCurrency: _currentUser?.preferredCurrency,
      ),
      AnalyticsScreen(
        analyticsService: _analyticsService,
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
        height: 68,
        decoration: BoxDecoration(
          color: Colors.white,
          border: const Border(
            top: BorderSide(color: Color(0xFFE2E8F0), width: 1),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: SafeArea(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(0, Icons.home_outlined, Icons.home_rounded, 'Home'),
              _buildNavItem(1, Icons.receipt_long_outlined, Icons.receipt_long_rounded, 'Activity'),
              _buildCenterAdvisorItem(2),
              _buildNavItem(3, Icons.insights_rounded, Icons.insights_rounded, 'Insights'),
              _buildNavItem(4, Icons.tune_rounded, Icons.tune_rounded, 'Settings'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData unselectedIcon, IconData selectedIcon, String label) {
    final isSelected = _currentIndex == index;
    return InkWell(
      onTap: () => setState(() => _currentIndex = index),
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? selectedIcon : unselectedIcon,
              size: 24,
              color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF94A3B8),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Elevated Glowing Center Advisor Icon (Screenshot 3)
  Widget _buildCenterAdvisorItem(int index) {
    final isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF2563EB),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2563EB).withOpacity(isSelected ? 0.45 : 0.25),
                  blurRadius: isSelected ? 12 : 6,
                  spreadRadius: isSelected ? 2 : 0,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Center(
              child: Icon(
                Icons.auto_awesome,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Advisor',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }
}
