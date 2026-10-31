import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kharcha_ai/core/constants/app_colors.dart';
import 'package:kharcha_ai/core/theme/theme_controller.dart';
import 'package:kharcha_ai/core/utils/currency_formatter.dart';
import 'package:kharcha_ai/models/bill_model.dart';
import 'package:kharcha_ai/models/dashboard_model.dart';
import 'package:kharcha_ai/models/expense_model.dart';
import 'package:kharcha_ai/models/income_model.dart';
import 'package:kharcha_ai/models/user_model.dart';
import 'package:kharcha_ai/screens/add_income_screen.dart';
import 'package:kharcha_ai/screens/analytics_screen.dart';
import 'package:kharcha_ai/screens/bills_screen.dart';
import 'package:kharcha_ai/screens/budget_screen.dart';
import 'package:kharcha_ai/screens/currency_settings_screen.dart';
import 'package:kharcha_ai/screens/financial_advisor_screen.dart';
import 'package:kharcha_ai/screens/income_detail_screen.dart';
import 'package:kharcha_ai/screens/income_screen.dart';
import 'package:kharcha_ai/screens/login_screen.dart';
import 'package:kharcha_ai/screens/profile_screen.dart';
import 'package:kharcha_ai/screens/recurring_expenses_screen.dart';
import 'package:kharcha_ai/screens/reports_screen.dart';
import 'package:kharcha_ai/screens/savings_goals_screen.dart';
import 'package:kharcha_ai/screens/scan_receipt_screen.dart';
import 'package:kharcha_ai/services/analytics_service.dart';
import 'package:kharcha_ai/services/auth_service.dart';
import 'package:kharcha_ai/services/bill_service.dart';
import 'package:kharcha_ai/services/budget_service.dart';
import 'package:kharcha_ai/services/currency_service.dart';
import 'package:kharcha_ai/services/dashboard_service.dart';
import 'package:kharcha_ai/services/expense_service.dart';
import 'package:kharcha_ai/services/financial_advisor_service.dart';
import 'package:kharcha_ai/services/income_service.dart';
import 'package:kharcha_ai/services/receipt_service.dart';
import 'package:kharcha_ai/services/recurring_service.dart';
import 'package:kharcha_ai/services/report_service.dart';
import 'package:kharcha_ai/services/saving_service.dart';
import 'package:kharcha_ai/widgets/add_expense_sheet.dart';
import 'package:kharcha_ai/widgets/category_icon_avatar.dart';
import 'package:kharcha_ai/widgets/empty_state_view.dart';
import 'package:kharcha_ai/widgets/fintech_card.dart';
import 'package:kharcha_ai/widgets/skeleton_loader.dart';

class DashboardScreen extends StatefulWidget {
  final AuthService authService;
  final ExpenseService? expenseService;
  final UserModel? initialUser;
  final Function(int)? onNavigateTab;

  const DashboardScreen({
    super.key,
    required this.authService,
    this.expenseService,
    this.initialUser,
    this.onNavigateTab,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late final ExpenseService _expenseService;
  late final DashboardService _dashboardService;
  late final CurrencyService _currencyService;
  late final IncomeService _incomeService;
  late final SavingService _savingService;
  late final BillService _billService;
  late final FinancialAdvisorService _advisorService;
  late UserModel? _currentUser;

  bool _isLoading = false;
  bool _hideBalance = false;
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DashboardFinancialSummaryModel? _financialSummary;
  List<ExpenseModel> _expenses = [];
  List<BillModel> _upcomingBills = [];
  String _selectedCategoryFilter = 'All';
  int _transactionTab = 0; // 0: Expenses, 1: Incomes

  final List<String> _categoryFilters = [
    'All',
    'Food',
    'Transport',
    'Shopping',
    'Bills',
    'Healthcare',
    'Education',
    'Entertainment',
    'Rent',
    'Travel',
    'Other'
  ];

  @override
  void initState() {
    super.initState();
    _currentUser = widget.initialUser;
    final client = widget.authService.apiClient;
    _expenseService = widget.expenseService ?? ExpenseService(apiClient: client);
    _dashboardService = DashboardService(apiClient: client);
    _currencyService = CurrencyService(apiClient: client);
    _incomeService = IncomeService(apiClient: client);
    _savingService = SavingService(apiClient: client);
    _billService = BillService(apiClient: client);
    _advisorService = FinancialAdvisorService(apiClient: client);

    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);

    try {
      final startOfMonth = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
      final endOfMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0, 23, 59, 59);

      final futures = await Future.wait([
        if (_currentUser == null) widget.authService.getProfile() else Future.value(_currentUser),
        _dashboardService.getFinancialSummary(
          month: _selectedMonth.month,
          year: _selectedMonth.year,
        ),
        _expenseService.getExpenses(
          category: _selectedCategoryFilter == 'All' ? null : _selectedCategoryFilter,
          startDate: startOfMonth,
          endDate: endOfMonth,
          limit: 40,
        ),
      ]);

      if (!mounted) return;

      setState(() {
        _currentUser ??= futures[0] as UserModel;
        _financialSummary = futures[1] as DashboardFinancialSummaryModel;
        _expenses = futures[2] as List<ExpenseModel>;
        _upcomingBills = _financialSummary?.upcomingBills ?? [];
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _prevMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1, 1);
    });
    _loadDashboardData();
  }

  void _nextMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 1);
    });
    _loadDashboardData();
  }

  Future<void> _pickMonthYear() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      helpText: 'Select Month & Year',
    );
    if (picked != null && mounted) {
      setState(() {
        _selectedMonth = DateTime(picked.year, picked.month, 1);
      });
      _loadDashboardData();
    }
  }

  void _resetToCurrentMonth() {
    final now = DateTime.now();
    setState(() {
      _selectedMonth = DateTime(now.year, now.month, 1);
    });
    _loadDashboardData();
  }

  void _openCurrencySettings() {
    final user = _currentUser ??
        UserModel(
          id: 0,
          email: 'user@kharcha.ai',
          fullName: 'User',
          isActive: true,
          preferredCurrency: _financialSummary?.currency ?? 'PKR',
          createdAt: DateTime.now(),
        );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CurrencySettingsScreen(
          currencyService: _currencyService,
          currentUser: user,
          onCurrencyChanged: (newCurrency) {
            setState(() {
              if (_currentUser != null) {
                _currentUser = _currentUser!.copyWith(preferredCurrency: newCurrency);
              }
            });
            _loadDashboardData();
          },
        ),
      ),
    ).then((_) => _loadDashboardData());
  }

  void _showAddExpenseSheet([ExpenseModel? expenseToEdit]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddExpenseSheet(
        expenseService: _expenseService,
        expenseToEdit: expenseToEdit,
        onSuccess: () {
          _loadDashboardData();
        },
      ),
    );
  }

  void _showAddIncomeScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddIncomeScreen(incomeService: _incomeService),
      ),
    ).then((_) => _loadDashboardData());
  }

  Future<void> _openScanReceiptScreen() async {
    final created = await Navigator.push<ExpenseModel>(
      context,
      MaterialPageRoute(
        builder: (context) => ScanReceiptScreen(
          receiptService: ReceiptScannerService(apiClient: widget.authService.apiClient),
          expenseService: _expenseService,
        ),
      ),
    );
    if (created != null && mounted) {
      _loadDashboardData();
    }
  }

  void _openBudgetScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BudgetScreen(
          budgetService: BudgetService(apiClient: widget.authService.apiClient),
        ),
      ),
    ).then((_) => _loadDashboardData());
  }

  void _openAnalyticsScreen() {
    if (widget.onNavigateTab != null) {
      widget.onNavigateTab!(2);
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AnalyticsScreen(
            analyticsService: AnalyticsService(apiClient: widget.authService.apiClient),
          ),
        ),
      );
    }
  }

  void _openSavingsGoalsScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SavingsGoalsScreen(savingService: _savingService),
      ),
    ).then((_) => _loadDashboardData());
  }

  void _openBillsScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BillsScreen(billService: _billService),
      ),
    ).then((_) => _loadDashboardData());
  }

  void _openAdvisorScreen() {
    if (widget.onNavigateTab != null) {
      widget.onNavigateTab!(3);
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => FinancialAdvisorScreen(advisorService: _advisorService),
        ),
      ).then((_) => _loadDashboardData());
    }
  }

  void _openRecurringScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RecurringExpensesScreen(
          recurringService: RecurringService(apiClient: widget.authService.apiClient),
        ),
      ),
    ).then((_) => _loadDashboardData());
  }

  void _openReportsScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReportsScreen(
          reportService: ReportService(apiClient: widget.authService.apiClient),
        ),
      ),
    );
  }

  Future<void> _handleDeleteExpense(ExpenseModel expense) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Expense'),
        content: Text('Are you sure you want to delete "${expense.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await _expenseService.deleteExpense(expense.id);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Expense deleted successfully'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
        _loadDashboardData();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log Out'),
        content: const Text('Do you want to log out of your KharchaAI account?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await widget.authService.logout();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => LoginScreen(authService: widget.authService),
        ),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeCurrency = _financialSummary?.currency ?? _currentUser?.preferredCurrency ?? 'PKR';
    final userName = _currentUser?.displayName ?? 'KharchaAI Member';

    final summaryCards = _financialSummary?.summaryCards;
    final monthlyIncome = summaryCards?.monthlyIncome ?? 0.0;
    final monthlyExpenses = summaryCards?.monthlyExpenses ?? 0.0;
    final netCashflow = summaryCards?.netCashflow ?? (monthlyIncome - monthlyExpenses);
    final monthlySavings = summaryCards?.monthlySavings ?? (netCashflow > 0 ? netCashflow : 0.0);
    final savingsRate = summaryCards?.savingsRate ?? 0.0;
    final isDeficit = summaryCards?.isDeficit ?? (monthlyExpenses > monthlyIncome);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Center(
                child: Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 20),
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'KharchaAI',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                ),
                Text(
                  'Hi, $userName',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          // Quick Currency Switcher Badge
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: InkWell(
              onTap: _openCurrencySettings,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkPrimarySurface : AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.primary.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      CurrencyFormatter.getSymbol(activeCurrency),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      activeCurrency,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: AppColors.primary,
                      ),
                    ),
                    const Icon(Icons.arrow_drop_down, size: 16, color: AppColors.primary),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            icon: Icon(
              isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              size: 20,
            ),
            tooltip: 'Toggle Theme',
            onPressed: () => ThemeController.instance.toggleTheme(),
          ),
          IconButton(
            icon: const Icon(Icons.person_outline_rounded),
            tooltip: 'Profile',
            onPressed: () {
              if (widget.onNavigateTab != null) {
                widget.onNavigateTab!(4);
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProfileScreen(
                      authService: widget.authService,
                      initialUser: _currentUser,
                    ),
                  ),
                ).then((_) => _loadDashboardData());
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: AppColors.error),
            tooltip: 'Log Out',
            onPressed: _handleLogout,
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadDashboardData,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 12.0),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Greeting Header
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10, top: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Salam,',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                userName,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Month & Year Navigator Header
                    _buildMonthNavigator(isDark, activeCurrency),
                    const SizedBox(height: 12),

                    // Prominent Deficit Alert Banner
                    if (isDeficit) ...[
                      _buildDeficitWarningBanner(isDark, summaryCards?.deficitWarningMessage, activeCurrency, monthlyExpenses - monthlyIncome),
                      const SizedBox(height: 14),
                    ],

                    // Hero Net Cashflow Card
                    _buildHeroBalanceCard(isDark, activeCurrency, netCashflow, monthlyIncome, monthlyExpenses, isDeficit),
                    const SizedBox(height: 16),

                    // The 4 Financial Summary Cards (Strict Month-Isolated Rule)
                    _buildFourSummaryCards(isDark, activeCurrency, monthlyIncome, monthlyExpenses, netCashflow, monthlySavings, savingsRate, isDeficit),
                    const SizedBox(height: 16),

                    // Month-over-Month Comparison
                    if (_financialSummary?.comparison != null) ...[
                      _buildMoMComparisonCard(isDark, activeCurrency, _financialSummary!.comparison),
                      const SizedBox(height: 16),
                    ],

                    // Category Spending Breakdown
                    if (_financialSummary != null && _financialSummary!.categoryBreakdown.isNotEmpty) ...[
                      _buildCategorySpendingSection(isDark, activeCurrency, _financialSummary!.categoryBreakdown),
                      const SizedBox(height: 16),
                    ],

                    // Budget Status & Upcoming Bills Row
                    _buildBudgetAndBillsRow(isDark, activeCurrency),
                    const SizedBox(height: 16),

                    // AI Financial Intelligence Insights (Module D)
                    if (_financialSummary != null && _financialSummary!.aiInsights.isNotEmpty) ...[
                      _buildAIInsightsSection(isDark, _financialSummary!.aiInsights),
                      const SizedBox(height: 16),
                    ],

                    // Quick Financial Tools Row
                    _buildQuickToolsRow(isDark),
                    const SizedBox(height: 20),

                    // Recent Activity (Expenses & Incomes)
                    _buildRecentTransactionsSection(isDark, activeCurrency),
                    const SizedBox(height: 24),

                    // Multi-currency isolation status card
                    _buildBackendStatusCard(isDark, activeCurrency),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMonthNavigator(bool isDark, String activeCurrency) {
    final now = DateTime.now();
    final isCurrentMonth = _selectedMonth.year == now.year && _selectedMonth.month == now.month;
    final monthFormat = DateFormat('MMMM yyyy');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkCardBorder : AppColors.cardBorder,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded),
            tooltip: 'Previous Month',
            onPressed: _prevMonth,
          ),
          InkWell(
            onTap: _pickMonthYear,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                children: [
                  const Icon(Icons.calendar_month_outlined, size: 18, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text(
                    monthFormat.format(_selectedMonth),
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_drop_down, size: 18, color: AppColors.textSecondary),
                ],
              ),
            ),
          ),
          Row(
            children: [
              if (!isCurrentMonth)
                TextButton(
                  onPressed: _resetToCurrentMonth,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'Today',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
                  ),
                ),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded),
                tooltip: 'Next Month',
                onPressed: _nextMonth,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDeficitWarningBanner(bool isDark, String? warningMessage, String currency, double deficitAmount) {
    final displayMsg = warningMessage ??
        'Your expenses exceed your income by ${CurrencyFormatter.format(deficitAmount, currency: currency)} this month. Review your budget to restore balance.';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.error, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.error.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Text(
                      'Monthly Deficit Alert',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: AppColors.error,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  displayMsg,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFFB71C1C),
                    height: 1.35,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroBalanceCard(
    bool isDark,
    String userCurrency,
    double netCashflow,
    double monthlyIncome,
    double monthlyExpenses,
    bool isDeficit,
  ) {
    return FintechCard(
      gradient: isDeficit
          ? const LinearGradient(
              colors: [Color(0xFF2D1515), Color(0xFF4A1E1E)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            )
          : AppColors.navyHeroGradient,
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Net Cashflow • ${DateFormat('MMM yyyy').format(_selectedMonth)}',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              IconButton(
                constraints: const BoxConstraints(),
                padding: EdgeInsets.zero,
                icon: Icon(
                  _hideBalance ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: Colors.white70,
                  size: 18,
                ),
                onPressed: () => setState(() => _hideBalance = !_hideBalance),
                tooltip: _hideBalance ? 'Show balance' : 'Hide balance',
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                _hideBalance
                    ? '••••••••'
                    : '${netCashflow >= 0 ? '+' : ''}${CurrencyFormatter.format(netCashflow, currency: userCurrency)}',
                style: TextStyle(
                  color: isDeficit ? const Color(0xFFFF8A80) : Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.8,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isDeficit ? AppColors.error.withOpacity(0.3) : AppColors.success.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isDeficit ? 'DEFICIT' : 'SURPLUS',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isDeficit ? const Color(0xFFFF8A80) : const Color(0xFFA5D6A7),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Income & Expense quick row inside hero
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.success.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.arrow_downward_rounded, color: AppColors.success, size: 16),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Month Income',
                            style: TextStyle(color: Colors.white60, fontSize: 11),
                          ),
                          Text(
                            _hideBalance
                                ? '••••'
                                : CurrencyFormatter.format(monthlyIncome, currency: userCurrency, compact: true),
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(width: 1, height: 32, color: Colors.white12),
                const SizedBox(width: 14),
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.error.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.arrow_upward_rounded, color: AppColors.error, size: 16),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Month Expenses',
                            style: TextStyle(color: Colors.white60, fontSize: 11),
                          ),
                          Text(
                            _hideBalance
                                ? '••••'
                                : CurrencyFormatter.format(monthlyExpenses, currency: userCurrency, compact: true),
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Hero CTA Buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _showAddExpenseSheet(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.deepNavy,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.remove_circle_outline, size: 16, color: AppColors.error),
                  label: const Text('Add Kharcha', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _showAddIncomeScreen,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.16),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.add_circle_outline, size: 16, color: AppColors.success),
                  label: const Text('Add Income', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFourSummaryCards(
    bool isDark,
    String userCurrency,
    double monthlyIncome,
    double monthlyExpenses,
    double netCashflow,
    double monthlySavings,
    double savingsRate,
    bool isDeficit,
  ) {
    return Column(
      children: [
        Row(
          children: [
            // Card 1: Monthly Income
            Expanded(
              child: _buildMetricCard(
                isDark: isDark,
                title: 'Monthly Income',
                amount: CurrencyFormatter.format(monthlyIncome, currency: userCurrency),
                icon: Icons.trending_up_rounded,
                iconColor: AppColors.success,
                bgColor: AppColors.successBg,
                badgeText: 'Earned',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => IncomeScreen(incomeService: _incomeService),
                    ),
                  ).then((_) => _loadDashboardData());
                },
              ),
            ),
            const SizedBox(width: 12),

            // Card 2: Monthly Expenses
            Expanded(
              child: _buildMetricCard(
                isDark: isDark,
                title: 'Monthly Expenses',
                amount: CurrencyFormatter.format(monthlyExpenses, currency: userCurrency),
                icon: Icons.trending_down_rounded,
                iconColor: AppColors.error,
                bgColor: AppColors.errorBg,
                badgeText: 'Spent',
                onTap: () => setState(() => _transactionTab = 0),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            // Card 3: Net Cashflow
            Expanded(
              child: _buildMetricCard(
                isDark: isDark,
                title: 'Net Cashflow',
                amount: '${netCashflow >= 0 ? '+' : ''}${CurrencyFormatter.format(netCashflow, currency: userCurrency)}',
                icon: Icons.account_balance_wallet_rounded,
                iconColor: isDeficit ? AppColors.error : AppColors.success,
                bgColor: isDeficit ? AppColors.errorBg : AppColors.successBg,
                badgeText: isDeficit ? 'Deficit' : 'Surplus',
              ),
            ),
            const SizedBox(width: 12),

            // Card 4: Monthly Savings & Rate
            Expanded(
              child: _buildMetricCard(
                isDark: isDark,
                title: 'Monthly Savings',
                amount: CurrencyFormatter.format(monthlySavings, currency: userCurrency),
                icon: Icons.savings_rounded,
                iconColor: AppColors.primary,
                bgColor: AppColors.primarySurface,
                badgeText: '${savingsRate.toStringAsFixed(1)}% saved',
                onTap: _openSavingsGoalsScreen,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required bool isDark,
    required String title,
    required String amount,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required String badgeText,
    VoidCallback? onTap,
  }) {
    return FintechCard(
      padding: const EdgeInsets.all(14),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkBackground : const Color(0xFFF2F4F7),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  badgeText,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            amount,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildMoMComparisonCard(bool isDark, String userCurrency, IncomeVsExpenseComparisonModel comp) {
    final incomeDiff = comp.currentMonthIncome - comp.prevMonthIncome;
    final expenseDiff = comp.currentMonthExpenses - comp.prevMonthExpenses;

    return FintechCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Month-over-Month Comparison',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                ),
              ),
              const Icon(Icons.compare_arrows_rounded, size: 18, color: AppColors.primary),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildMoMColumn(
                  isDark: isDark,
                  label: 'Income vs Prev',
                  currentVal: comp.currentMonthIncome,
                  diff: incomeDiff,
                  isPositiveGood: true,
                  userCurrency: userCurrency,
                ),
              ),
              Container(width: 1, height: 42, color: isDark ? AppColors.darkCardBorder : AppColors.cardBorder),
              Expanded(
                child: _buildMoMColumn(
                  isDark: isDark,
                  label: 'Expense vs Prev',
                  currentVal: comp.currentMonthExpenses,
                  diff: expenseDiff,
                  isPositiveGood: false,
                  userCurrency: userCurrency,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMoMColumn({
    required bool isDark,
    required String label,
    required double currentVal,
    required double diff,
    required bool isPositiveGood,
    required String userCurrency,
  }) {
    final isGood = isPositiveGood ? diff >= 0 : diff <= 0;
    final diffColor = isGood ? AppColors.success : AppColors.error;
    final diffIcon = diff >= 0 ? Icons.arrow_upward : Icons.arrow_downward;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                CurrencyFormatter.format(currentVal, currency: userCurrency, compact: true),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 6),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(diffIcon, size: 12, color: diffColor),
                  Text(
                    CurrencyFormatter.format(diff.abs(), currency: userCurrency, compact: true),
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: diffColor),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySpendingSection(
    bool isDark,
    String userCurrency,
    List<DashboardCategorySpendingModel> breakdown,
  ) {
    return FintechCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Month Spending Breakdown',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                ),
              ),
              GestureDetector(
                onTap: _openAnalyticsScreen,
                child: const Text(
                  'Analytics →',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...breakdown.take(4).map((cat) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: Column(
                children: [
                  Row(
                    children: [
                      CategoryIconAvatar(category: cat.category, size: 28, iconSize: 14, borderRadius: 8),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          cat.category,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                          ),
                        ),
                      ),
                      Text(
                        CurrencyFormatter.format(cat.amount, currency: userCurrency),
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${cat.percentage.toStringAsFixed(0)}%',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (cat.percentage / 100).clamp(0.0, 1.0),
                      minHeight: 5,
                      backgroundColor: isDark ? const Color(0xFF1E2838) : const Color(0xFFF2F4F7),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        CategoryIconAvatar.getMeta(cat.category).color,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildBudgetAndBillsRow(bool isDark, String userCurrency) {
    final budgetStatus = _financialSummary?.budgetStatus;
    final upcomingBills = _financialSummary?.upcomingBills ?? _upcomingBills;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Budget Status Card
        Expanded(
          child: FintechCard(
            padding: const EdgeInsets.all(16),
            onTap: _openBudgetScreen,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.pie_chart_outline_rounded, color: Colors.orange, size: 16),
                    ),
                    const Spacer(),
                    const Icon(Icons.chevron_right, size: 16, color: AppColors.textMuted),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Monthly Budget',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                if (budgetStatus != null && budgetStatus.totalBudget != null && budgetStatus.totalBudget! > 0) ...[
                  Text(
                    budgetStatus.isOverBudget
                        ? 'Over by ${CurrencyFormatter.format((budgetStatus.budgetSpent! - budgetStatus.totalBudget!), currency: userCurrency, compact: true)}'
                        : '${CurrencyFormatter.format(budgetStatus.remainingBudget ?? 0, currency: userCurrency, compact: true)} left',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: budgetStatus.isOverBudget ? AppColors.error : AppColors.success,
                    ),
                  ),
                ] else ...[
                  const Text(
                    'Set a budget',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),

        // Upcoming Bills Card
        Expanded(
          child: FintechCard(
            padding: const EdgeInsets.all(16),
            onTap: _openBillsScreen,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.purpleBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.receipt_long_rounded, color: AppColors.purpleAccent, size: 16),
                    ),
                    const Spacer(),
                    const Icon(Icons.chevron_right, size: 16, color: AppColors.textMuted),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Upcoming Bills',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  upcomingBills.isNotEmpty ? '${upcomingBills.length} pending' : 'All bills paid!',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: upcomingBills.isNotEmpty ? AppColors.warning : AppColors.success,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAIInsightsSection(bool isDark, List<dynamic> aiInsights) {
    return FintechCard(
      onTap: _openAdvisorScreen,
      gradient: LinearGradient(
        colors: isDark
            ? [const Color(0xFF1E284A), const Color(0xFF161F30)]
            : [AppColors.primarySurface, Colors.white],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Financial Intelligence',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text('AI', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  aiInsights.first.title ?? 'Smart cashflow observations ready for your review.',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.primary, size: 20),
        ],
      ),
    );
  }

  Widget _buildQuickToolsRow(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Financial Tools',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildToolChip(
                isDark: isDark,
                label: 'Budgets',
                icon: Icons.pie_chart_outline_rounded,
                color: Colors.orange,
                onTap: _openBudgetScreen,
              ),
              const SizedBox(width: 8),
              _buildToolChip(
                isDark: isDark,
                label: 'Income Hub',
                icon: Icons.arrow_downward_rounded,
                color: AppColors.success,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => IncomeScreen(incomeService: _incomeService),
                    ),
                  ).then((_) => _loadDashboardData());
                },
              ),
              const SizedBox(width: 8),
              _buildToolChip(
                isDark: isDark,
                label: 'Recurring',
                icon: Icons.event_repeat_rounded,
                color: AppColors.primary,
                onTap: _openRecurringScreen,
              ),
              const SizedBox(width: 8),
              _buildToolChip(
                isDark: isDark,
                label: 'Reports',
                icon: Icons.assessment_outlined,
                color: AppColors.cyanAccent,
                onTap: _openReportsScreen,
              ),
              const SizedBox(width: 8),
              _buildToolChip(
                isDark: isDark,
                label: 'Receipt AI',
                icon: Icons.document_scanner_outlined,
                color: AppColors.purpleAccent,
                onTap: _openScanReceiptScreen,
              ),
              const SizedBox(width: 8),
              _buildToolChip(
                isDark: isDark,
                label: 'Currencies',
                icon: Icons.currency_exchange,
                color: Colors.teal,
                onTap: _openCurrencySettings,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildToolChip({
    required bool isDark,
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: isDark ? AppColors.darkCardBorder : AppColors.cardBorder),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentTransactionsSection(bool isDark, String userCurrency) {
    final recentIncomes = _financialSummary?.recentIncomes ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Tab Selector Row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                _buildSegmentButton('Expenses', 0, isDark),
                const SizedBox(width: 8),
                _buildSegmentButton('Income', 1, isDark),
              ],
            ),
            TextButton.icon(
              onPressed: () {
                if (_transactionTab == 0) {
                  if (widget.onNavigateTab != null) {
                    widget.onNavigateTab!(1);
                  }
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => IncomeScreen(incomeService: _incomeService),
                    ),
                  ).then((_) => _loadDashboardData());
                }
              },
              icon: const Icon(Icons.arrow_forward_rounded, size: 14, color: AppColors.primary),
              label: const Text(
                'View All',
                style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        if (_transactionTab == 0) ...[
          // Category Filter Chips
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _categoryFilters.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final cat = _categoryFilters[index];
                final isSelected = _selectedCategoryFilter == cat;
                return FilterChip(
                  label: Text(cat),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() => _selectedCategoryFilter = cat);
                    _loadDashboardData();
                  },
                  selectedColor: isDark ? AppColors.darkPrimarySurface : AppColors.primarySurface,
                  checkmarkColor: AppColors.primary,
                  labelStyle: TextStyle(
                    color: isSelected
                        ? AppColors.primary
                        : (isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 12,
                  ),
                  backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: isSelected
                          ? AppColors.primary
                          : (isDark ? AppColors.darkCardBorder : AppColors.cardBorder),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),

          if (_isLoading && _expenses.isEmpty) ...[
            const SkeletonList(count: 3),
          ] else if (_expenses.isEmpty) ...[
            EmptyStateView(
              icon: Icons.receipt_outlined,
              title: 'No Expenses Recorded',
              description: 'No expenses logged for ${DateFormat('MMMM yyyy').format(_selectedMonth)}.',
              actionText: 'Add Kharcha',
              actionIcon: Icons.add,
              onAction: () => _showAddExpenseSheet(),
            ),
          ] else ...[
            ..._expenses.map((expense) => _buildExpenseTile(expense, isDark, userCurrency)),
          ],
        ] else ...[
          // Income Tab Content
          if (_isLoading && recentIncomes.isEmpty) ...[
            const SkeletonList(count: 3),
          ] else if (recentIncomes.isEmpty) ...[
            EmptyStateView(
              icon: Icons.account_balance_wallet_outlined,
              title: 'No Income Recorded',
              description: 'No income logged for ${DateFormat('MMMM yyyy').format(_selectedMonth)}.',
              actionText: 'Add Income',
              actionIcon: Icons.add,
              onAction: _showAddIncomeScreen,
            ),
          ] else ...[
            ...recentIncomes.map((income) => _buildIncomeTile(income, isDark, userCurrency)),
          ],
        ],
      ],
    );
  }

  Widget _buildSegmentButton(String label, int index, bool isDark) {
    final isSelected = _transactionTab == index;
    return InkWell(
      onTap: () => setState(() => _transactionTab = index),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary
              : (isDark ? AppColors.darkSurface : const Color(0xFFF2F4F7)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: isSelected ? Colors.white : (isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
          ),
        ),
      ),
    );
  }

  Widget _buildExpenseTile(ExpenseModel expense, bool isDark, String userCurrency) {
    return FintechCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          CategoryIconAvatar(category: expense.category),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  expense.title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Text(
                      expense.formattedDate,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.darkTextMuted : AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkBackground : const Color(0xFFF2F4F7),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        expense.paymentMethod,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '-${CurrencyFormatter.format(expense.amount, currency: expense.currency)}',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: AppColors.error,
                ),
              ),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_horiz, size: 18, color: isDark ? AppColors.darkTextMuted : AppColors.textMuted),
                onSelected: (val) {
                  if (val == 'edit') {
                    _showAddExpenseSheet(expense);
                  } else if (val == 'delete') {
                    _handleDeleteExpense(expense);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined, size: 18),
                        SizedBox(width: 8),
                        Text('Edit'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                        SizedBox(width: 8),
                        Text('Delete', style: TextStyle(color: AppColors.error)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIncomeTile(IncomeModel income, bool isDark, String userCurrency) {
    return FintechCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => IncomeDetailScreen(
              income: income,
              incomeService: _incomeService,
            ),
          ),
        ).then((_) => _loadDashboardData());
      },
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.successBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.arrow_downward_rounded, color: AppColors.success, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  income.title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Text(
                      income.formattedDate,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.darkTextMuted : AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkBackground : const Color(0xFFF2F4F7),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        income.paymentMethod,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Text(
            '+${CurrencyFormatter.format(income.amount, currency: income.currency)}',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: AppColors.success,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackendStatusCard(bool isDark, String activeCurrency) {
    return FintechCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: AppColors.successBg,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.verified_rounded, color: AppColors.success, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Multi-Currency Financial Platform Verified',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Display currency: $activeCurrency • Base rates active',
                  style: TextStyle(
                    fontSize: 11,
                    fontFamily: 'monospace',
                    color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
