class BillModel {
  final int id;
  final int userId;
  final String title;
  final String category;
  final double amount;
  final DateTime dueDate;
  final String status;
  final String frequency;
  final bool reminderEnabled;
  final DateTime? paidDate;
  final int? linkedExpenseId;
  final bool isOverdue;
  final DateTime createdAt;
  final DateTime updatedAt;

  const BillModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.category,
    required this.amount,
    required this.dueDate,
    required this.status,
    required this.frequency,
    required this.reminderEnabled,
    this.paidDate,
    this.linkedExpenseId,
    required this.isOverdue,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isPaid => status == 'paid';
  bool get isPending => status == 'unpaid';

  factory BillModel.fromJson(Map<String, dynamic> json) {
    return BillModel(
      id: json['id'] as int,
      userId: json['user_id'] as int,
      title: json['title'] as String? ?? '',
      category: json['category'] as String? ?? 'Other',
      amount: double.tryParse(json['amount']?.toString() ?? '0') ?? 0.0,
      dueDate: json['due_date'] != null
          ? DateTime.parse(json['due_date'] as String)
          : DateTime.now(),
      status: json['status'] as String? ?? 'unpaid',
      frequency: json['frequency'] as String? ?? 'one_time',
      reminderEnabled: json['reminder_enabled'] as bool? ?? true,
      paidDate: json['paid_date'] != null
          ? DateTime.parse(json['paid_date'] as String)
          : null,
      linkedExpenseId: json['linked_expense_id'] as int?,
      isOverdue: json['is_overdue'] as bool? ?? false,
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
      'title': title,
      'category': category,
      'amount': amount,
      'due_date': '${dueDate.year.toString().padLeft(4, '0')}-${dueDate.month.toString().padLeft(2, '0')}-${dueDate.day.toString().padLeft(2, '0')}',
      'frequency': frequency,
      'reminder_enabled': reminderEnabled,
    };
  }
}

class BillListModel {
  final int total;
  final double totalAmount;
  final List<BillModel> items;

  const BillListModel({
    required this.total,
    required this.totalAmount,
    required this.items,
  });

  factory BillListModel.fromJson(Map<String, dynamic> json) {
    final list = (json['items'] as List<dynamic>?) ?? [];
    return BillListModel(
      total: json['total'] as int? ?? list.length,
      totalAmount: double.tryParse(json['total_amount']?.toString() ?? '0') ?? 0.0,
      items: list.map((item) => BillModel.fromJson(item as Map<String, dynamic>)).toList(),
    );
  }
}

class BillSummaryModel {
  final double totalPendingAmount;
  final int pendingCount;
  final double totalOverdueAmount;
  final int overdueCount;
  final double totalPaidThisMonth;
  final int paidCountThisMonth;
  final List<BillModel> upcomingBills;

  const BillSummaryModel({
    required this.totalPendingAmount,
    required this.pendingCount,
    required this.totalOverdueAmount,
    required this.overdueCount,
    required this.totalPaidThisMonth,
    required this.paidCountThisMonth,
    required this.upcomingBills,
  });

  factory BillSummaryModel.fromJson(Map<String, dynamic> json) {
    final upcomingList = (json['upcoming_bills'] as List<dynamic>?) ?? [];
    return BillSummaryModel(
      totalPendingAmount: double.tryParse(json['total_pending_amount']?.toString() ?? '0') ?? 0.0,
      pendingCount: json['pending_count'] as int? ?? 0,
      totalOverdueAmount: double.tryParse(json['total_overdue_amount']?.toString() ?? '0') ?? 0.0,
      overdueCount: json['overdue_count'] as int? ?? 0,
      totalPaidThisMonth: double.tryParse(json['total_paid_this_month']?.toString() ?? '0') ?? 0.0,
      paidCountThisMonth: json['paid_count_this_month'] as int? ?? 0,
      upcomingBills: upcomingList.map((item) => BillModel.fromJson(item as Map<String, dynamic>)).toList(),
    );
  }

  double get unpaidAmount => totalPendingAmount;
  int get unpaidCount => pendingCount;
}
