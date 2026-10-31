import 'package:flutter_test/flutter_test.dart';
import 'package:kharcha_ai/models/income_model.dart';

void main() {
  group('Phase 6 Income Models Serialization Tests', () {
    test('IncomeSourceModel.fromJson parses fields correctly', () {
      final json = {
        'id': 1,
        'user_id': 10,
        'name': 'Freelance',
        'description': 'Client contract development',
        'is_active': true,
        'created_at': '2026-10-31T10:00:00Z',
      };

      final model = IncomeSourceModel.fromJson(json);
      expect(model.id, 1);
      expect(model.userId, 10);
      expect(model.name, 'Freelance');
      expect(model.description, 'Client contract development');
      expect(model.isActive, true);
      expect(model.createdAt.year, 2026);
    });

    test('IncomeModel.fromJson correctly parses Decimal amounts and fields', () {
      final json = {
        'id': 42,
        'user_id': 10,
        'source_id': 1,
        'source_name': 'Salary',
        'title': 'Monthly Software Developer Salary',
        'amount': '150000.50',
        'currency': 'PKR',
        'income_date': '2026-10-31',
        'payment_method': 'Bank Transfer',
        'description': 'Direct bank deposit',
        'created_at': '2026-10-31T10:00:00Z',
        'updated_at': '2026-10-31T10:05:00Z',
      };

      final model = IncomeModel.fromJson(json);
      expect(model.id, 42);
      expect(model.userId, 10);
      expect(model.sourceId, 1);
      expect(model.sourceName, 'Salary');
      expect(model.title, 'Monthly Software Developer Salary');
      expect(model.amount, 150000.50);
      expect(model.currency, 'PKR');
      expect(model.paymentMethod, 'Bank Transfer');
      expect(model.description, 'Direct bank deposit');
      expect(model.incomeDate.day, 31);
    });

    test('IncomeListModel.fromJson parses paginated items and total amount', () {
      final json = {
        'total': 1,
        'page': 1,
        'page_size': 20,
        'total_amount': '50000.00',
        'items': [
          {
            'id': 1,
            'user_id': 10,
            'source_id': null,
            'source_name': null,
            'title': 'Tutoring',
            'amount': '50000.00',
            'currency': 'PKR',
            'income_date': '2026-10-30',
            'payment_method': 'Cash',
            'created_at': '2026-10-30T10:00:00Z',
            'updated_at': '2026-10-30T10:00:00Z',
          }
        ]
      };

      final listModel = IncomeListModel.fromJson(json);
      expect(listModel.total, 1);
      expect(listModel.page, 1);
      expect(listModel.totalAmount, 50000.00);
      expect(listModel.items.length, 1);
      expect(listModel.items.first.title, 'Tutoring');
    });

    test('IncomeSummaryModel.fromJson parses source breakdown and average', () {
      final json = {
        'total_income': '100000.00',
        'total_transactions': 2,
        'currency': 'PKR',
        'month': 10,
        'year': 2026,
        'average_income_per_entry': '50000.00',
        'source_breakdown': [
          {
            'source_id': 1,
            'source_name': 'Salary',
            'total_amount': '80000.00',
            'percentage': 80.0,
            'transaction_count': 1,
          },
          {
            'source_id': 2,
            'source_name': 'Freelance',
            'total_amount': '20000.00',
            'percentage': 20.0,
            'transaction_count': 1,
          }
        ]
      };

      final summary = IncomeSummaryModel.fromJson(json);
      expect(summary.totalIncome, 100000.00);
      expect(summary.totalTransactions, 2);
      expect(summary.averageIncomePerEntry, 50000.00);
      expect(summary.sourceBreakdown.length, 2);
      expect(summary.sourceBreakdown[0].sourceName, 'Salary');
      expect(summary.sourceBreakdown[0].percentage, 80.0);
    });
  });
}
