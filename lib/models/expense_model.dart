import 'package:intl/intl.dart';
import 'package:kharcha_ai/core/utils/currency_formatter.dart';

class ExpenseModel {
  final int id;
  final int userId;
  final String title;
  final double amount;
  final String currency;
  final String category;
  final String? description;
  final DateTime expenseDate;
  final String paymentMethod;
  final DateTime createdAt;
  final DateTime updatedAt;

  ExpenseModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.amount,
    this.currency = 'PKR',
    required this.category,
    this.description,
    required this.expenseDate,
    required this.paymentMethod,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ExpenseModel.fromJson(Map<String, dynamic> json) {
    return ExpenseModel(
      id: json['id'] as int,
      userId: json['user_id'] as int,
      title: json['title'] as String,
      amount: double.tryParse(json['amount'].toString()) ?? 0.0,
      currency: json['currency'] as String? ?? 'PKR',
      category: json['category'] as String,
      description: json['description'] as String?,
      expenseDate: json['expense_date'] != null
          ? DateTime.parse(json['expense_date'] as String)
          : DateTime.now(),
      paymentMethod: json['payment_method'] as String? ?? 'Cash',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : (json['created_at'] != null
              ? DateTime.parse(json['created_at'] as String)
              : DateTime.now()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'amount': amount.toStringAsFixed(2),
      'currency': currency,
      'category': category,
      'description': description,
      'expense_date': DateFormat('yyyy-MM-dd').format(expenseDate),
      'payment_method': paymentMethod,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  String get formattedAmount {
    return CurrencyFormatter.format(amount, currency: currency);
  }

  String get formattedDate {
    return DateFormat('MMM dd, yyyy').format(expenseDate);
  }
}
