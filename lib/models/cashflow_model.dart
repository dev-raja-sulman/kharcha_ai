class DailyCashflowPointModel {
  final String date;
  final double income;
  final double expense;
  final double net;

  const DailyCashflowPointModel({
    required this.date,
    required this.income,
    required this.expense,
    required this.net,
  });

  factory DailyCashflowPointModel.fromJson(Map<String, dynamic> json) {
    return DailyCashflowPointModel(
      date: json['date'] as String? ?? '',
      income: double.tryParse(json['income']?.toString() ?? '0') ?? 0.0,
      expense: double.tryParse(json['expense']?.toString() ?? '0') ?? 0.0,
      net: double.tryParse(json['net']?.toString() ?? '0') ?? 0.0,
    );
  }
}

class CashflowOverviewModel {
  final int month;
  final int year;
  final String currency;
  final double totalIncome;
  final double totalExpenses;
  final double netCashflow;
  final double savingsRate;
  final double? totalBudget;
  final double? remainingBudget;
  final double? budgetUsedPercentage;
  final String healthStatus;
  final String healthTitle;
  final String healthSummary;
  final List<DailyCashflowPointModel> dailyTrends;

  const CashflowOverviewModel({
    required this.month,
    required this.year,
    this.currency = 'PKR',
    required this.totalIncome,
    required this.totalExpenses,
    required this.netCashflow,
    required this.savingsRate,
    this.totalBudget,
    this.remainingBudget,
    this.budgetUsedPercentage,
    required this.healthStatus,
    required this.healthTitle,
    required this.healthSummary,
    required this.dailyTrends,
  });

  factory CashflowOverviewModel.fromJson(Map<String, dynamic> json) {
    final rawTrends = json['daily_trends'] as List<dynamic>? ?? [];
    return CashflowOverviewModel(
      month: json['month'] as int? ?? DateTime.now().month,
      year: json['year'] as int? ?? DateTime.now().year,
      currency: json['currency'] as String? ?? 'PKR',
      totalIncome: double.tryParse(json['total_income']?.toString() ?? '0') ?? 0.0,
      totalExpenses: double.tryParse(json['total_expenses']?.toString() ?? '0') ?? 0.0,
      netCashflow: double.tryParse(json['net_cashflow']?.toString() ?? '0') ?? 0.0,
      savingsRate: (json['savings_rate'] as num?)?.toDouble() ?? 0.0,
      totalBudget: json['total_budget'] != null
          ? double.tryParse(json['total_budget'].toString())
          : null,
      remainingBudget: json['remaining_budget'] != null
          ? double.tryParse(json['remaining_budget'].toString())
          : null,
      budgetUsedPercentage: (json['budget_used_percentage'] as num?)?.toDouble(),
      healthStatus: json['health_status'] as String? ?? 'no_data',
      healthTitle: json['health_title'] as String? ?? 'Financial Status',
      healthSummary: json['health_summary'] as String? ?? '',
      dailyTrends: rawTrends
          .map((e) => DailyCashflowPointModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
