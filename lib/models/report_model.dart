class CategoryReportItem {
  final String category;
  final double totalAmount;
  final double percentage;
  final int count;

  CategoryReportItem({
    required this.category,
    required this.totalAmount,
    required this.percentage,
    required this.count,
  });

  String get formattedAmount => 'PKR ${totalAmount.toStringAsFixed(2)}';
  String get formattedPercentage => '${percentage.toStringAsFixed(1)}%';

  factory CategoryReportItem.fromJson(Map<String, dynamic> json) {
    return CategoryReportItem(
      category: json['category'] as String,
      totalAmount: double.tryParse(json['total_amount'].toString()) ?? 0.0,
      percentage: double.tryParse(json['percentage'].toString()) ?? 0.0,
      count: json['count'] as int? ?? 0,
    );
  }
}

class TrendPoint {
  final String label;
  final DateTime? pointDate;
  final double amount;
  final int count;

  TrendPoint({
    required this.label,
    this.pointDate,
    required this.amount,
    required this.count,
  });

  String get formattedAmount => 'PKR ${amount.toStringAsFixed(2)}';

  factory TrendPoint.fromJson(Map<String, dynamic> json) {
    return TrendPoint(
      label: json['label'] as String,
      pointDate: json['point_date'] != null ? DateTime.parse(json['point_date'] as String) : null,
      amount: double.tryParse(json['amount'].toString()) ?? 0.0,
      count: json['count'] as int? ?? 0,
    );
  }
}

class RecurringVsRegularBreakdown {
  final double recurringAmount;
  final int recurringCount;
  final double recurringPercentage;
  final double regularAmount;
  final int regularCount;
  final double regularPercentage;

  RecurringVsRegularBreakdown({
    required this.recurringAmount,
    required this.recurringCount,
    required this.recurringPercentage,
    required this.regularAmount,
    required this.regularCount,
    required this.regularPercentage,
  });

  String get formattedRecurringAmount => 'PKR ${recurringAmount.toStringAsFixed(2)}';
  String get formattedRegularAmount => 'PKR ${regularAmount.toStringAsFixed(2)}';

  factory RecurringVsRegularBreakdown.fromJson(Map<String, dynamic> json) {
    return RecurringVsRegularBreakdown(
      recurringAmount: double.tryParse(json['recurring_amount'].toString()) ?? 0.0,
      recurringCount: json['recurring_count'] as int? ?? 0,
      recurringPercentage: double.tryParse(json['recurring_percentage'].toString()) ?? 0.0,
      regularAmount: double.tryParse(json['regular_amount'].toString()) ?? 0.0,
      regularCount: json['regular_count'] as int? ?? 0,
      regularPercentage: double.tryParse(json['regular_percentage'].toString()) ?? 0.0,
    );
  }
}

class PeriodComparisonData {
  final DateTime previousStartDate;
  final DateTime previousEndDate;
  final double previousExpenditure;
  final int previousCount;
  final double difference;
  final double percentageChange;
  final String trend; // "increased", "decreased", "unchanged", "no_previous_data"

  PeriodComparisonData({
    required this.previousStartDate,
    required this.previousEndDate,
    required this.previousExpenditure,
    required this.previousCount,
    required this.difference,
    required this.percentageChange,
    required this.trend,
  });

  String get formattedPreviousExpenditure => 'PKR ${previousExpenditure.toStringAsFixed(2)}';
  String get formattedDifference =>
      '${difference >= 0 ? '+' : ''}PKR ${difference.abs().toStringAsFixed(2)}';

  factory PeriodComparisonData.fromJson(Map<String, dynamic> json) {
    return PeriodComparisonData(
      previousStartDate: DateTime.parse(json['previous_start_date'] as String),
      previousEndDate: DateTime.parse(json['previous_end_date'] as String),
      previousExpenditure: double.tryParse(json['previous_expenditure'].toString()) ?? 0.0,
      previousCount: json['previous_count'] as int? ?? 0,
      difference: double.tryParse(json['difference'].toString()) ?? 0.0,
      percentageChange: double.tryParse(json['percentage_change'].toString()) ?? 0.0,
      trend: json['trend'] as String? ?? 'unchanged',
    );
  }
}

class AdvancedReportModel {
  final String reportType;
  final DateTime startDate;
  final DateTime endDate;
  final double totalExpenditure;
  final int totalExpenses;
  final double averageDailySpending;
  final CategoryReportItem? highestSpendingCategory;
  final List<CategoryReportItem> categoryBreakdown;
  final List<TrendPoint> spendingTrends;
  final RecurringVsRegularBreakdown recurringVsRegular;
  final PeriodComparisonData? periodComparison;
  final String generatedAt;

  AdvancedReportModel({
    required this.reportType,
    required this.startDate,
    required this.endDate,
    required this.totalExpenditure,
    required this.totalExpenses,
    required this.averageDailySpending,
    this.highestSpendingCategory,
    required this.categoryBreakdown,
    required this.spendingTrends,
    required this.recurringVsRegular,
    this.periodComparison,
    required this.generatedAt,
  });

  String get formattedTotalExpenditure => 'PKR ${totalExpenditure.toStringAsFixed(2)}';
  String get formattedAverageDaily => 'PKR ${averageDailySpending.toStringAsFixed(2)}';

  factory AdvancedReportModel.fromJson(Map<String, dynamic> json) {
    return AdvancedReportModel(
      reportType: json['report_type'] as String? ?? 'monthly',
      startDate: DateTime.parse(json['start_date'] as String),
      endDate: DateTime.parse(json['end_date'] as String),
      totalExpenditure: double.tryParse(json['total_expenditure'].toString()) ?? 0.0,
      totalExpenses: json['total_expenses'] as int? ?? 0,
      averageDailySpending: double.tryParse(json['average_daily_spending'].toString()) ?? 0.0,
      highestSpendingCategory: json['highest_spending_category'] != null
          ? CategoryReportItem.fromJson(json['highest_spending_category'] as Map<String, dynamic>)
          : null,
      categoryBreakdown: (json['category_breakdown'] as List<dynamic>?)
              ?.map((item) => CategoryReportItem.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
      spendingTrends: (json['spending_trends'] as List<dynamic>?)
              ?.map((item) => TrendPoint.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
      recurringVsRegular: RecurringVsRegularBreakdown.fromJson(
        json['recurring_vs_regular'] as Map<String, dynamic>? ?? {},
      ),
      periodComparison: json['period_comparison'] != null
          ? PeriodComparisonData.fromJson(json['period_comparison'] as Map<String, dynamic>)
          : null,
      generatedAt: json['generated_at'] as String? ?? '',
    );
  }
}
