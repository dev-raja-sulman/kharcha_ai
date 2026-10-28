import 'package:flutter_test/flutter_test.dart';
import 'package:kharcha_ai/models/expense_model.dart';
import 'package:kharcha_ai/models/expense_summary.dart';

void main() {
  group('ExpenseModel Tests', () {
    test('ExpenseModel.fromJson parses fields and amounts accurately', () {
      final json = {
        'id': 101,
        'user_id': 5,
        'title': 'Dinner with family',
        'amount': '3250.75',
        'category': 'Food',
        'description': 'Biryani & Cold drinks',
        'expense_date': '2026-10-28',
        'payment_method': 'EasyPaisa',
        'created_at': '2026-10-28T14:00:00Z',
        'updated_at': '2026-10-28T14:00:00Z',
      };

      final expense = ExpenseModel.fromJson(json);

      expect(expense.id, 101);
      expect(expense.userId, 5);
      expect(expense.title, 'Dinner with family');
      expect(expense.amount, 3250.75);
      expect(expense.category, 'Food');
      expect(expense.paymentMethod, 'EasyPaisa');
      expect(expense.description, 'Biryani & Cold drinks');
      expect(expense.formattedAmount, 'PKR 3,250.75');
      expect(expense.formattedDate, 'Oct 28, 2026');
    });

    test('ExpenseSummaryModel.fromJson parses category aggregations correctly', () {
      final json = {
        'total_amount': '15000.00',
        'total_count': 4,
        'by_category': [
          {
            'category': 'Food',
            'total_amount': '9000.00',
            'count': 2,
            'percentage': 60.0,
          },
          {
            'category': 'Bills',
            'total_amount': '6000.00',
            'count': 2,
            'percentage': 40.0,
          }
        ],
        'by_payment_method': [
          {
            'payment_method': 'Cash',
            'total_amount': '9000.00',
            'count': 2,
          },
          {
            'payment_method': 'Card',
            'total_amount': '6000.00',
            'count': 2,
          }
        ],
        'start_date': '2026-10-01',
        'end_date': '2026-10-31',
      };

      final summary = ExpenseSummaryModel.fromJson(json);

      expect(summary.totalAmount, 15000.00);
      expect(summary.totalCount, 4);
      expect(summary.formattedTotal, 'PKR 15,000.00');
      expect(summary.byCategory.length, 2);
      expect(summary.byCategory.first.category, 'Food');
      expect(summary.byCategory.first.percentage, 60.0);
    });
  });
}
