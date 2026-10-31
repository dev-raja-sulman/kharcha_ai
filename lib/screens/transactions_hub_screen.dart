import 'package:flutter/material.dart';
import 'package:kharcha_ai/core/constants/app_colors.dart';
import 'package:kharcha_ai/models/user_model.dart';
import 'package:kharcha_ai/screens/expense_screen.dart';
import 'package:kharcha_ai/screens/income_screen.dart';
import 'package:kharcha_ai/services/expense_service.dart';
import 'package:kharcha_ai/services/income_service.dart';

class TransactionsHubScreen extends StatefulWidget {
  final ExpenseService expenseService;
  final IncomeService incomeService;
  final UserModel? currentUser;

  const TransactionsHubScreen({
    super.key,
    required this.expenseService,
    required this.incomeService,
    this.currentUser,
  });

  @override
  State<TransactionsHubScreen> createState() => _TransactionsHubScreenState();
}

class _TransactionsHubScreenState extends State<TransactionsHubScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
      appBar: AppBar(
        title: const Text('Transactions'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkBackground : const Color(0xFFF2F4F7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorSize: TabBarIndicatorSize.tab,
              indicator: BoxDecoration(
                color: isDark ? AppColors.darkSurface : Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              labelColor: AppColors.primary,
              unselectedLabelColor: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
              labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
              dividerColor: Colors.transparent,
              tabs: const [
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.arrow_upward_rounded, size: 16, color: AppColors.error),
                      SizedBox(width: 6),
                      Text('Expenses'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.arrow_downward_rounded, size: 16, color: AppColors.success),
                      SizedBox(width: 6),
                      Text('Income'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          ExpenseScreen(
            expenseService: widget.expenseService,
            preferredCurrency: widget.currentUser?.preferredCurrency,
          ),
          IncomeScreen(
            incomeService: widget.incomeService,
          ),
        ],
      ),
    );
  }
}
