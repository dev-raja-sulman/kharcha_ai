class AdvisorOverviewModel {
  final double totalIncomeThisMonth;
  final double totalExpensesThisMonth;
  final double netCashflow;
  final double savingsRate;
  final int activeGoalsCount;
  final double totalSavingsAccumulated;
  final int pendingBillsCount;
  final double pendingBillsTotal;
  final int overdueBillsCount;
  final int financialHealthScore;
  final String financialHealthStatus;

  const AdvisorOverviewModel({
    required this.totalIncomeThisMonth,
    required this.totalExpensesThisMonth,
    required this.netCashflow,
    required this.savingsRate,
    required this.activeGoalsCount,
    required this.totalSavingsAccumulated,
    required this.pendingBillsCount,
    required this.pendingBillsTotal,
    required this.overdueBillsCount,
    required this.financialHealthScore,
    required this.financialHealthStatus,
  });

  factory AdvisorOverviewModel.fromJson(Map<String, dynamic> json) {
    return AdvisorOverviewModel(
      totalIncomeThisMonth: double.tryParse(json['total_income_this_month']?.toString() ?? '0') ?? 0.0,
      totalExpensesThisMonth: double.tryParse(json['total_expenses_this_month']?.toString() ?? '0') ?? 0.0,
      netCashflow: double.tryParse(json['net_cashflow']?.toString() ?? '0') ?? 0.0,
      savingsRate: (json['savings_rate'] as num?)?.toDouble() ?? 0.0,
      activeGoalsCount: json['active_goals_count'] as int? ?? 0,
      totalSavingsAccumulated: double.tryParse(json['total_savings_accumulated']?.toString() ?? '0') ?? 0.0,
      pendingBillsCount: json['pending_bills_count'] as int? ?? 0,
      pendingBillsTotal: double.tryParse(json['pending_bills_total']?.toString() ?? '0') ?? 0.0,
      overdueBillsCount: json['overdue_bills_count'] as int? ?? 0,
      financialHealthScore: json['financial_health_score'] as int? ?? 0,
      financialHealthStatus: json['financial_health_status'] as String? ?? 'Moderate',
    );
  }
}

class AdvisorInsightItemModel {
  final String type; // strength | improvement | recommendation | alert
  final String title;
  final String description;
  final String impact;

  const AdvisorInsightItemModel({
    required this.type,
    required this.title,
    required this.description,
    required this.impact,
  });

  factory AdvisorInsightItemModel.fromJson(Map<String, dynamic> json) {
    return AdvisorInsightItemModel(
      type: json['type'] as String? ?? 'recommendation',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      impact: json['impact'] as String? ?? 'medium',
    );
  }
}

class AdvisorInsightsModel {
  final String summaryHeadline;
  final String providerUsed;
  final List<AdvisorInsightItemModel> insights;
  final String keyRecommendation;

  const AdvisorInsightsModel({
    required this.summaryHeadline,
    required this.providerUsed,
    required this.insights,
    required this.keyRecommendation,
  });

  factory AdvisorInsightsModel.fromJson(Map<String, dynamic> json) {
    final list = (json['insights'] as List<dynamic>?) ?? [];
    return AdvisorInsightsModel(
      summaryHeadline: json['summary_headline'] as String? ?? '',
      providerUsed: json['provider_used'] as String? ?? 'rule_engine',
      insights: list.map((item) => AdvisorInsightItemModel.fromJson(item as Map<String, dynamic>)).toList(),
      keyRecommendation: json['key_recommendation'] as String? ?? '',
    );
  }
}

class AdvisorChatResponseModel {
  final String reply;
  final String providerUsed;
  final Map<String, dynamic> groundedMetrics;
  final List<String> suggestedFollowups;

  const AdvisorChatResponseModel({
    required this.reply,
    required this.providerUsed,
    required this.groundedMetrics,
    required this.suggestedFollowups,
  });

  factory AdvisorChatResponseModel.fromJson(Map<String, dynamic> json) {
    final followups = (json['suggested_followups'] as List<dynamic>?) ?? [];
    return AdvisorChatResponseModel(
      reply: json['reply'] as String? ?? '',
      providerUsed: json['provider_used'] as String? ?? 'rule_engine',
      groundedMetrics: (json['grounded_metrics'] as Map<String, dynamic>?) ?? {},
      suggestedFollowups: followups.map((e) => e.toString()).toList(),
    );
  }
}
