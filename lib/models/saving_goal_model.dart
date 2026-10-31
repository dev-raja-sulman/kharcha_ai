class ContributionModel {
  final int id;
  final int goalId;
  final int userId;
  final double amount;
  final DateTime contributionDate;
  final String? notes;
  final DateTime createdAt;

  const ContributionModel({
    required this.id,
    required this.goalId,
    required this.userId,
    required this.amount,
    required this.contributionDate,
    this.notes,
    required this.createdAt,
  });

  factory ContributionModel.fromJson(Map<String, dynamic> json) {
    return ContributionModel(
      id: json['id'] as int,
      goalId: json['goal_id'] as int,
      userId: json['user_id'] as int,
      amount: double.tryParse(json['amount']?.toString() ?? '0') ?? 0.0,
      contributionDate: json['contribution_date'] != null
          ? DateTime.parse(json['contribution_date'] as String)
          : DateTime.now(),
      notes: json['notes'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }
}

class SavingGoalModel {
  final int id;
  final int userId;
  final String title;
  final String? description;
  final double targetAmount;
  final double currentAmount;
  final DateTime startDate;
  final DateTime targetDate;
  final String status;
  final double remainingAmount;
  final double progressPercentage;
  final DateTime createdAt;
  final DateTime updatedAt;

  const SavingGoalModel({
    required this.id,
    required this.userId,
    required this.title,
    this.description,
    required this.targetAmount,
    required this.currentAmount,
    required this.startDate,
    required this.targetDate,
    required this.status,
    required this.remainingAmount,
    required this.progressPercentage,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isCompleted => status == 'completed' || currentAmount >= targetAmount;

  factory SavingGoalModel.fromJson(Map<String, dynamic> json) {
    return SavingGoalModel(
      id: json['id'] as int,
      userId: json['user_id'] as int,
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      targetAmount: double.tryParse(json['target_amount']?.toString() ?? '0') ?? 0.0,
      currentAmount: double.tryParse(json['current_amount']?.toString() ?? '0') ?? 0.0,
      startDate: json['start_date'] != null
          ? DateTime.parse(json['start_date'] as String)
          : DateTime.now(),
      targetDate: json['target_date'] != null
          ? DateTime.parse(json['target_date'] as String)
          : DateTime.now(),
      status: json['status'] as String? ?? 'in_progress',
      remainingAmount: double.tryParse(json['remaining_amount']?.toString() ?? '0') ?? 0.0,
      progressPercentage: (json['progress_percentage'] as num?)?.toDouble() ?? 0.0,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'target_amount': targetAmount.toStringAsFixed(2),
      'current_amount': currentAmount.toStringAsFixed(2),
      'start_date': startDate.toIso8601String().split('T').first,
      'target_date': targetDate.toIso8601String().split('T').first,
      'status': status,
    };
  }
}

class SavingGoalListModel {
  final int total;
  final double totalSavings;
  final List<SavingGoalModel> items;

  const SavingGoalListModel({
    required this.total,
    required this.totalSavings,
    required this.items,
  });

  factory SavingGoalListModel.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? [];
    return SavingGoalListModel(
      total: json['total'] as int? ?? 0,
      totalSavings: double.tryParse(json['total_savings']?.toString() ?? '0') ?? 0.0,
      items: rawItems.map((e) => SavingGoalModel.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}
