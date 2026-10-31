class IncomeSourceModel {
  final int id;
  final int? userId;
  final String name;
  final String? description;
  final bool isActive;
  final DateTime createdAt;

  const IncomeSourceModel({
    required this.id,
    this.userId,
    required this.name,
    this.description,
    this.isActive = true,
    required this.createdAt,
  });

  factory IncomeSourceModel.fromJson(Map<String, dynamic> json) {
    return IncomeSourceModel(
      id: json['id'] as int,
      userId: json['user_id'] as int?,
      name: json['name'] as String? ?? 'Other',
      description: json['description'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'description': description,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

class IncomeModel {
  final int id;
  final int userId;
  final int? sourceId;
  final String? sourceName;
  final String title;
  final double amount;
  final String currency;
  final DateTime incomeDate;
  final String paymentMethod;
  final String? description;
  final DateTime createdAt;
  final DateTime updatedAt;

  const IncomeModel({
    required this.id,
    required this.userId,
    this.sourceId,
    this.sourceName,
    required this.title,
    required this.amount,
    this.currency = 'PKR',
    required this.incomeDate,
    this.paymentMethod = 'Bank Transfer',
    this.description,
    required this.createdAt,
    required this.updatedAt,
  });

  factory IncomeModel.fromJson(Map<String, dynamic> json) {
    return IncomeModel(
      id: json['id'] as int,
      userId: json['user_id'] as int,
      sourceId: json['source_id'] as int?,
      sourceName: json['source_name'] as String?,
      title: json['title'] as String? ?? '',
      amount: double.tryParse(json['amount']?.toString() ?? '0') ?? 0.0,
      currency: json['currency'] as String? ?? 'PKR',
      incomeDate: json['income_date'] != null
          ? DateTime.parse(json['income_date'] as String)
          : DateTime.now(),
      paymentMethod: json['payment_method'] as String? ?? 'Bank Transfer',
      description: json['description'] as String?,
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
      'user_id': userId,
      'source_id': sourceId,
      'source_name': sourceName,
      'title': title,
      'amount': amount.toStringAsFixed(2),
      'currency': currency,
      'income_date': incomeDate.toIso8601String().split('T').first,
      'payment_method': paymentMethod,
      'description': description,
    };
  }

  String get formattedDate {
    return '${incomeDate.year}-${incomeDate.month.toString().padLeft(2, '0')}-${incomeDate.day.toString().padLeft(2, '0')}';
  }
}

class IncomeListModel {
  final int total;
  final int page;
  final int pageSize;
  final double totalAmount;
  final List<IncomeModel> items;

  const IncomeListModel({
    required this.total,
    required this.page,
    required this.pageSize,
    required this.totalAmount,
    required this.items,
  });

  factory IncomeListModel.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? [];
    return IncomeListModel(
      total: json['total'] as int? ?? 0,
      page: json['page'] as int? ?? 1,
      pageSize: json['page_size'] as int? ?? 20,
      totalAmount: double.tryParse(json['total_amount']?.toString() ?? '0') ?? 0.0,
      items: rawItems.map((e) => IncomeModel.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}

class SourceBreakdownModel {
  final int? sourceId;
  final String sourceName;
  final double totalAmount;
  final double percentage;
  final int transactionCount;

  const SourceBreakdownModel({
    this.sourceId,
    required this.sourceName,
    required this.totalAmount,
    required this.percentage,
    required this.transactionCount,
  });

  factory SourceBreakdownModel.fromJson(Map<String, dynamic> json) {
    return SourceBreakdownModel(
      sourceId: json['source_id'] as int?,
      sourceName: json['source_name'] as String? ?? 'Other',
      totalAmount: double.tryParse(json['total_amount']?.toString() ?? '0') ?? 0.0,
      percentage: (json['percentage'] as num?)?.toDouble() ?? 0.0,
      transactionCount: json['transaction_count'] as int? ?? 0,
    );
  }
}

class IncomeSummaryModel {
  final double totalIncome;
  final int totalTransactions;
  final String currency;
  final int? month;
  final int? year;
  final List<SourceBreakdownModel> sourceBreakdown;
  final double averageIncomePerEntry;

  const IncomeSummaryModel({
    required this.totalIncome,
    required this.totalTransactions,
    this.currency = 'PKR',
    this.month,
    this.year,
    required this.sourceBreakdown,
    required this.averageIncomePerEntry,
  });

  factory IncomeSummaryModel.fromJson(Map<String, dynamic> json) {
    final rawBreakdown = json['source_breakdown'] as List<dynamic>? ?? [];
    return IncomeSummaryModel(
      totalIncome: double.tryParse(json['total_income']?.toString() ?? '0') ?? 0.0,
      totalTransactions: json['total_transactions'] as int? ?? 0,
      currency: json['currency'] as String? ?? 'PKR',
      month: json['month'] as int?,
      year: json['year'] as int?,
      sourceBreakdown: rawBreakdown.map((e) => SourceBreakdownModel.fromJson(e as Map<String, dynamic>)).toList(),
      averageIncomePerEntry: double.tryParse(json['average_income_per_entry']?.toString() ?? '0') ?? 0.0,
    );
  }

  int get totalCount => totalTransactions;
}
