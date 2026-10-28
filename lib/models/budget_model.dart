class BudgetModel {
  final int id;
  final int userId;
  final String name;
  final double amount;
  final String? category;
  final int month;
  final int year;
  final DateTime startDate;
  final DateTime endDate;
  final double spent;
  final double remaining;
  final double percentageUsed;
  final String alertLevel; // 'normal', 'warning_50', 'warning_80', 'exceeded_100'
  final String alertMessage;
  final DateTime createdAt;
  final DateTime updatedAt;

  const BudgetModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.amount,
    this.category,
    required this.month,
    required this.year,
    required this.startDate,
    required this.endDate,
    required this.spent,
    required this.remaining,
    required this.percentageUsed,
    required this.alertLevel,
    required this.alertMessage,
    required this.createdAt,
    required this.updatedAt,
  });

  factory BudgetModel.fromJson(Map<String, dynamic> json) {
    return BudgetModel(
      id: json['id'] as int,
      userId: json['user_id'] as int,
      name: json['name']?.toString() ?? '',
      amount: double.tryParse(json['amount'].toString()) ?? 0.0,
      category: json['category']?.toString(),
      month: json['month'] as int,
      year: json['year'] as int,
      startDate: DateTime.parse(json['start_date'].toString()),
      endDate: DateTime.parse(json['end_date'].toString()),
      spent: double.tryParse(json['spent'].toString()) ?? 0.0,
      remaining: double.tryParse(json['remaining'].toString()) ?? 0.0,
      percentageUsed: (json['percentage_used'] as num?)?.toDouble() ?? 0.0,
      alertLevel: json['alert_level']?.toString() ?? 'normal',
      alertMessage: json['alert_message']?.toString() ?? '',
      createdAt: DateTime.parse(json['created_at'].toString()),
      updatedAt: DateTime.parse(json['updated_at'].toString()),
    );
  }

  String get formattedAmount => 'PKR ${amount.toStringAsFixed(2)}';
  String get formattedSpent => 'PKR ${spent.toStringAsFixed(2)}';
  String get formattedRemaining => 'PKR ${remaining.toStringAsFixed(2)}';
  bool get isOverBudget => percentageUsed >= 100.0;
}
