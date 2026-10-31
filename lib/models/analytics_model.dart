class CategorySpendingModel {
  final String category;
  final double amount;
  final double percentage;
  final int count;

  const CategorySpendingModel({
    required this.category,
    required this.amount,
    required this.percentage,
    required this.count,
  });

  factory CategorySpendingModel.fromJson(Map<String, dynamic> json) {
    return CategorySpendingModel(
      category: json['category']?.toString() ?? 'Other',
      amount: double.tryParse(json['amount'].toString()) ?? 0.0,
      percentage: (json['percentage'] as num?)?.toDouble() ?? 0.0,
      count: json['count'] as int? ?? 0,
    );
  }
}

class MonthComparisonModel {
  final double currentMonthTotal;
  final double previousMonthTotal;
  final double difference;
  final double percentageChange;
  final String trend; // 'increased', 'decreased', 'unchanged', 'no_previous_data'

  const MonthComparisonModel({
    required this.currentMonthTotal,
    required this.previousMonthTotal,
    required this.difference,
    required this.percentageChange,
    required this.trend,
  });

  factory MonthComparisonModel.fromJson(Map<String, dynamic> json) {
    return MonthComparisonModel(
      currentMonthTotal: double.tryParse(json['current_month_total'].toString()) ?? 0.0,
      previousMonthTotal: double.tryParse(json['previous_month_total'].toString()) ?? 0.0,
      difference: double.tryParse(json['difference'].toString()) ?? 0.0,
      percentageChange: (json['percentage_change'] as num?)?.toDouble() ?? 0.0,
      trend: json['trend']?.toString() ?? 'no_previous_data',
    );
  }
}

class SpendingInsightItemModel {
  final String type;
  final String title;
  final String message;
  final String severity; // 'info', 'warning', 'success'
  final String? category;

  const SpendingInsightItemModel({
    required this.type,
    required this.title,
    required this.message,
    required this.severity,
    this.category,
  });

  factory SpendingInsightItemModel.fromJson(Map<String, dynamic> json) {
    return SpendingInsightItemModel(
      type: json['type']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      severity: json['severity']?.toString() ?? 'info',
      category: json['category']?.toString(),
    );
  }
}

class SpendingAnalyticsModel {
  final int month;
  final int year;
  final double totalSpent;
  final int totalTransactions;
  final double averageDailySpending;
  final CategorySpendingModel? highestCategory;
  final List<CategorySpendingModel> categoryBreakdown;
  final MonthComparisonModel monthComparison;

  const SpendingAnalyticsModel({
    required this.month,
    required this.year,
    required this.totalSpent,
    required this.totalTransactions,
    required this.averageDailySpending,
    this.highestCategory,
    required this.categoryBreakdown,
    required this.monthComparison,
  });

  factory SpendingAnalyticsModel.fromJson(Map<String, dynamic> json) {
    final catList = (json['category_breakdown'] as List<dynamic>?)
            ?.map((e) => CategorySpendingModel.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];

    CategorySpendingModel? topCat;
    if (json['highest_spending_category'] != null) {
      topCat = CategorySpendingModel.fromJson(
          json['highest_spending_category'] as Map<String, dynamic>);
    }

    return SpendingAnalyticsModel(
      month: json['month'] as int,
      year: json['year'] as int,
      totalSpent: double.tryParse(json['total_spent'].toString()) ?? 0.0,
      totalTransactions: json['total_transactions'] as int? ?? 0,
      averageDailySpending:
          double.tryParse(json['average_daily_spending'].toString()) ?? 0.0,
      highestCategory: topCat,
      categoryBreakdown: catList,
      monthComparison: MonthComparisonModel.fromJson(
          json['month_comparison'] as Map<String, dynamic>),
    );
  }

  double get momChangePercentage => monthComparison.percentageChange;
  double get dailyAverage => averageDailySpending;
  int get transactionCount => totalTransactions;
}
