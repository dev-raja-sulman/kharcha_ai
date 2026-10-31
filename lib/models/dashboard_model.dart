import 'package:kharcha_ai/core/utils/currency_formatter.dart';
import 'package:kharcha_ai/models/bill_model.dart';
import 'package:kharcha_ai/models/cashflow_model.dart';
import 'package:kharcha_ai/models/expense_model.dart';
import 'package:kharcha_ai/models/financial_advisor_model.dart';
import 'package:kharcha_ai/models/income_model.dart';

class DashboardSummaryCardsModel {
  final double monthlyIncome;
  final double monthlyExpenses;
  final double netCashflow;
  final double monthlySavings;
  final double savingsRate;
  final bool isDeficit;
  final String? deficitWarningMessage;

  DashboardSummaryCardsModel({
    required this.monthlyIncome,
    required this.monthlyExpenses,
    required this.netCashflow,
    required this.monthlySavings,
    required this.savingsRate,
    required this.isDeficit,
    this.deficitWarningMessage,
  });

  factory DashboardSummaryCardsModel.fromJson(Map<String, dynamic> json) {
    return DashboardSummaryCardsModel(
      monthlyIncome: double.tryParse(json['monthly_income']?.toString() ?? '0') ?? 0.0,
      monthlyExpenses: double.tryParse(json['monthly_expenses']?.toString() ?? '0') ?? 0.0,
      netCashflow: double.tryParse(json['net_cashflow']?.toString() ?? '0') ?? 0.0,
      monthlySavings: double.tryParse(json['monthly_savings']?.toString() ?? '0') ?? 0.0,
      savingsRate: (json['savings_rate'] as num?)?.toDouble() ?? 0.0,
      isDeficit: json['is_deficit'] as bool? ?? false,
      deficitWarningMessage: json['deficit_warning_message'] as String?,
    );
  }
}

class IncomeVsExpenseComparisonModel {
  final double currentMonthIncome;
  final double currentMonthExpenses;
  final double currentMonthNet;
  final double prevMonthIncome;
  final double prevMonthExpenses;
  final double prevMonthNet;

  IncomeVsExpenseComparisonModel({
    required this.currentMonthIncome,
    required this.currentMonthExpenses,
    required this.currentMonthNet,
    required this.prevMonthIncome,
    required this.prevMonthExpenses,
    required this.prevMonthNet,
  });

  factory IncomeVsExpenseComparisonModel.fromJson(Map<String, dynamic> json) {
    return IncomeVsExpenseComparisonModel(
      currentMonthIncome: double.tryParse(json['current_month_income']?.toString() ?? '0') ?? 0.0,
      currentMonthExpenses: double.tryParse(json['current_month_expenses']?.toString() ?? '0') ?? 0.0,
      currentMonthNet: double.tryParse(json['current_month_net']?.toString() ?? '0') ?? 0.0,
      prevMonthIncome: double.tryParse(json['prev_month_income']?.toString() ?? '0') ?? 0.0,
      prevMonthExpenses: double.tryParse(json['prev_month_expenses']?.toString() ?? '0') ?? 0.0,
      prevMonthNet: double.tryParse(json['prev_month_net']?.toString() ?? '0') ?? 0.0,
    );
  }
}

class DashboardCategorySpendingModel {
  final String category;
  final double amount;
  final double percentage;
  final int transactionCount;

  DashboardCategorySpendingModel({
    required this.category,
    required this.amount,
    required this.percentage,
    required this.transactionCount,
  });

  factory DashboardCategorySpendingModel.fromJson(Map<String, dynamic> json) {
    return DashboardCategorySpendingModel(
      category: json['category'] as String? ?? 'Other',
      amount: double.tryParse(json['amount']?.toString() ?? '0') ?? 0.0,
      percentage: (json['percentage'] as num?)?.toDouble() ?? 0.0,
      transactionCount: json['transaction_count'] as int? ?? 0,
    );
  }
}

class DashboardBudgetStatusModel {
  final double? totalBudget;
  final double? budgetSpent;
  final double? remainingBudget;
  final double? percentageUsed;
  final bool isOverBudget;

  DashboardBudgetStatusModel({
    this.totalBudget,
    this.budgetSpent,
    this.remainingBudget,
    this.percentageUsed,
    required this.isOverBudget,
  });

  factory DashboardBudgetStatusModel.fromJson(Map<String, dynamic> json) {
    return DashboardBudgetStatusModel(
      totalBudget: json['total_budget'] != null ? double.tryParse(json['total_budget'].toString()) : null,
      budgetSpent: json['budget_spent'] != null ? double.tryParse(json['budget_spent'].toString()) : null,
      remainingBudget: json['remaining_budget'] != null ? double.tryParse(json['remaining_budget'].toString()) : null,
      percentageUsed: (json['percentage_used'] as num?)?.toDouble(),
      isOverBudget: json['is_over_budget'] as bool? ?? false,
    );
  }
}

class DashboardFinancialSummaryModel {
  final int month;
  final int year;
  final String currency;
  final DashboardSummaryCardsModel summaryCards;
  final IncomeVsExpenseComparisonModel comparison;
  final List<DashboardCategorySpendingModel> categoryBreakdown;
  final List<DailyCashflowPointModel> dailyTrends;
  final List<IncomeModel> recentIncomes;
  final List<ExpenseModel> recentExpenses;
  final List<BillModel> upcomingBills;
  final DashboardBudgetStatusModel? budgetStatus;
  final List<AdvisorInsightItemModel> aiInsights;
  final String healthStatus;
  final String healthTitle;
  final String healthSummary;

  DashboardFinancialSummaryModel({
    required this.month,
    required this.year,
    required this.currency,
    required this.summaryCards,
    required this.comparison,
    required this.categoryBreakdown,
    required this.dailyTrends,
    required this.recentIncomes,
    required this.recentExpenses,
    required this.upcomingBills,
    this.budgetStatus,
    required this.aiInsights,
    required this.healthStatus,
    required this.healthTitle,
    required this.healthSummary,
  });

  factory DashboardFinancialSummaryModel.fromJson(Map<String, dynamic> json) {
    final currencyStr = json['currency'] as String? ?? 'PKR';

    return DashboardFinancialSummaryModel(
      month: json['month'] as int,
      year: json['year'] as int,
      currency: currencyStr,
      summaryCards: DashboardSummaryCardsModel.fromJson(
        json['summary_cards'] as Map<String, dynamic>? ?? {},
      ),
      comparison: IncomeVsExpenseComparisonModel.fromJson(
        json['comparison'] as Map<String, dynamic>? ?? {},
      ),
      categoryBreakdown: (json['category_breakdown'] as List<dynamic>?)
              ?.map((c) => DashboardCategorySpendingModel.fromJson(c as Map<String, dynamic>))
              .toList() ??
          [],
      dailyTrends: (json['daily_trends'] as List<dynamic>?)
              ?.map((t) => DailyCashflowPointModel.fromJson(t as Map<String, dynamic>))
              .toList() ??
          [],
      recentIncomes: (json['recent_incomes'] as List<dynamic>?)
              ?.map((i) => IncomeModel.fromJson(i as Map<String, dynamic>))
              .toList() ??
          [],
      recentExpenses: (json['recent_expenses'] as List<dynamic>?)
              ?.map((e) => ExpenseModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      upcomingBills: (json['upcoming_bills'] as List<dynamic>?)
              ?.map((b) => BillModel.fromJson(b as Map<String, dynamic>))
              .toList() ??
          [],
      budgetStatus: json['budget_status'] != null
          ? DashboardBudgetStatusModel.fromJson(json['budget_status'] as Map<String, dynamic>)
          : null,
      aiInsights: (json['ai_insights'] as List<dynamic>?)
              ?.map((a) => AdvisorInsightItemModel.fromJson(a as Map<String, dynamic>))
              .toList() ??
          [],
      healthStatus: json['health_status'] as String? ?? 'no_data',
      healthTitle: json['health_title'] as String? ?? 'Financial Overview',
      healthSummary: json['health_summary'] as String? ?? '',
    );
  }

  String formatAmount(double amount) => CurrencyFormatter.format(amount, currency: currency);
}
