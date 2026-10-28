import 'package:intl/intl.dart';

class ExpenseModel {
  final int id;
  final int userId;
  final String title;
  final double amount;
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
      category: json['category'] as String,
      description: json['description'] as String?,
      expenseDate: DateTime.parse(json['expense_date'] as String),
      paymentMethod: json['payment_method'] as String? ?? 'Cash',
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'amount': amount.toStringAsFixed(2),
      'category': category,
      'description': description,
      'expense_date': DateFormat('yyyy-MM-dd').format(expenseDate),
      'payment_method': paymentMethod,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  String get formattedAmount {
    final formatter = NumberFormat('#,##0.00', 'en_US');
    return 'PKR ${formatter.format(amount)}';
  }

  String get formattedDate {
    return DateFormat('MMM dd, yyyy').format(expenseDate);
  }
}
