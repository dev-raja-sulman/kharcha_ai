class RecurringExpenseModel {
  final int id;
  final int userId;
  final String title;
  final double amount;
  final String category;
  final String? description;
  final String frequency;
  final String paymentMethod;
  final DateTime startDate;
  final DateTime? endDate;
  final DateTime nextScheduledDate;
  final DateTime? lastGeneratedDate;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  RecurringExpenseModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.amount,
    required this.category,
    this.description,
    required this.frequency,
    required this.paymentMethod,
    required this.startDate,
    this.endDate,
    required this.nextScheduledDate,
    this.lastGeneratedDate,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isActive => status == 'active';
  bool get isPaused => status == 'paused';
  bool get isCancelled => status == 'cancelled';
  bool get isCompleted => status == 'completed';

  String get formattedAmount => 'PKR ${amount.toStringAsFixed(2)}';
  String get formattedFrequency =>
      frequency.isNotEmpty ? '${frequency[0].toUpperCase()}${frequency.substring(1)}' : '';
  String get formattedNextDate =>
      '${nextScheduledDate.year}-${nextScheduledDate.month.toString().padLeft(2, '0')}-${nextScheduledDate.day.toString().padLeft(2, '0')}';

  factory RecurringExpenseModel.fromJson(Map<String, dynamic> json) {
    return RecurringExpenseModel(
      id: json['id'] as int,
      userId: json['user_id'] as int,
      title: json['title'] as String,
      amount: double.tryParse(json['amount'].toString()) ?? 0.0,
      category: json['category'] as String,
      description: json['description'] as String?,
      frequency: json['frequency'] as String,
      paymentMethod: json['payment_method'] as String? ?? 'Cash',
      startDate: DateTime.parse(json['start_date'] as String),
      endDate: json['end_date'] != null ? DateTime.parse(json['end_date'] as String) : null,
      nextScheduledDate: DateTime.parse(json['next_scheduled_date'] as String),
      lastGeneratedDate: json['last_generated_date'] != null
          ? DateTime.parse(json['last_generated_date'] as String)
          : null,
      status: json['status'] as String? ?? 'active',
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'amount': amount,
      'category': category,
      'description': description,
      'frequency': frequency,
      'payment_method': paymentMethod,
      'start_date': startDate.toIso8601String().split('T')[0],
      if (endDate != null) 'end_date': endDate!.toIso8601String().split('T')[0],
      'next_scheduled_date': nextScheduledDate.toIso8601String().split('T')[0],
      if (lastGeneratedDate != null)
        'last_generated_date': lastGeneratedDate!.toIso8601String().split('T')[0],
      'status': status,
    };
  }
}
