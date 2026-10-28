import 'package:intl/intl.dart';

class CategorySummaryItem {
  final String category;
  final double totalAmount;
  final int count;
  final double percentage;

  CategorySummaryItem({
    required this.category,
    required this.totalAmount,
    required this.count,
    required this.percentage,
  });

  factory CategorySummaryItem.fromJson(Map<String, dynamic> json) {
    return CategorySummaryItem(
      category: json['category'] as String,
      totalAmount: double.tryParse(json['total_amount'].toString()) ?? 0.0,
      count: json['count'] as int? ?? 0,
      percentage: double.tryParse(json['percentage'].toString()) ?? 0.0,
    );
  }

  String get formattedAmount {
    final formatter = NumberFormat('#,##0.00', 'en_US');
    return 'PKR ${formatter.format(totalAmount)}';
  }
}

class PaymentMethodSummaryItem {
  final String paymentMethod;
  final double totalAmount;
  final int count;

  PaymentMethodSummaryItem({
    required this.paymentMethod,
    required this.totalAmount,
    required this.count,
  });

  factory PaymentMethodSummaryItem.fromJson(Map<String, dynamic> json) {
    return PaymentMethodSummaryItem(
      paymentMethod: json['payment_method'] as String? ?? 'Cash',
      totalAmount: double.tryParse(json['total_amount'].toString()) ?? 0.0,
      count: json['count'] as int? ?? 0,
    );
  }
}

class ExpenseSummaryModel {
  final double totalAmount;
  final int totalCount;
  final List<CategorySummaryItem> byCategory;
  final List<PaymentMethodSummaryItem> byPaymentMethod;
  final String? startDate;
  final String? endDate;

  ExpenseSummaryModel({
    required this.totalAmount,
    required this.totalCount,
    required this.byCategory,
    required this.byPaymentMethod,
    this.startDate,
    this.endDate,
  });

  factory ExpenseSummaryModel.fromJson(Map<String, dynamic> json) {
    return ExpenseSummaryModel(
      totalAmount: double.tryParse(json['total_amount'].toString()) ?? 0.0,
      totalCount: json['total_count'] as int? ?? 0,
      byCategory: (json['by_category'] as List<dynamic>?)
              ?.map((item) => CategorySummaryItem.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
      byPaymentMethod: (json['by_payment_method'] as List<dynamic>?)
              ?.map((item) => PaymentMethodSummaryItem.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
      startDate: json['start_date'] as String?,
      endDate: json['end_date'] as String?,
    );
  }

  String get formattedTotal {
    final formatter = NumberFormat('#,##0.00', 'en_US');
    return 'PKR ${formatter.format(totalAmount)}';
  }
}
