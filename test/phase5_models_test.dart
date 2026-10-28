import 'package:flutter_test/flutter_test.dart';
import 'package:kharcha_ai/models/recurring_expense_model.dart';
import 'package:kharcha_ai/models/report_model.dart';

void main() {
  group('Phase 5 RecurringExpenseModel & AdvancedReportModel Tests', () {
    test('RecurringExpenseModel.fromJson correctly parses fields and status getters', () {
      final json = {
        'id': 7,
        'user_id': 1,
        'title': 'Fiber Broadband',
        'amount': '3200.00',
        'category': 'Bills',
        'description': 'High speed connection',
        'frequency': 'monthly',
        'payment_method': 'Bank Transfer',
        'start_date': '2026-01-01',
        'end_date': '2026-12-31',
        'next_scheduled_date': '2026-02-01',
        'last_generated_date': '2026-01-01',
        'status': 'active',
        'created_at': '2026-01-01T00:00:00Z',
        'updated_at': '2026-01-01T00:00:00Z',
      };

      final rule = RecurringExpenseModel.fromJson(json);
      expect(rule.id, 7);
      expect(rule.title, 'Fiber Broadband');
      expect(rule.amount, 3200.00);
      expect(rule.category, 'Bills');
      expect(rule.frequency, 'monthly');
      expect(rule.isActive, isTrue);
      expect(rule.isPaused, isFalse);
      expect(rule.isCancelled, isFalse);
      expect(rule.formattedAmount, 'PKR 3200.00');
      expect(rule.formattedFrequency, 'Monthly');

      final serialized = rule.toJson();
      expect(serialized['title'], 'Fiber Broadband');
      expect(serialized['frequency'], 'monthly');
      expect(serialized['start_date'], '2026-01-01');
      expect(serialized['end_date'], '2026-12-31');
    });

    test('AdvancedReportModel.fromJson parses complete financial metrics', () {
      final json = {
        'report_type': 'monthly',
        'start_date': '2026-05-01',
        'end_date': '2026-05-31',
        'total_expenditure': '18500.00',
        'total_expenses': 12,
        'average_daily_spending': '596.77',
        'highest_spending_category': {
          'category': 'Bills',
          'total_amount': '9500.00',
          'percentage': 51.35,
          'count': 3,
        },
        'category_breakdown': [
          {
            'category': 'Bills',
            'total_amount': '9500.00',
            'percentage': 51.35,
            'count': 3,
          },
          {
            'category': 'Food',
            'total_amount': '6000.00',
            'percentage': 32.43,
            'count': 7,
          },
        ],
        'spending_trends': [
          {
            'label': 'May 01',
            'point_date': '2026-05-01',
            'amount': '3200.00',
            'count': 1,
          },
        ],
        'recurring_vs_regular': {
          'recurring_amount': '9500.00',
          'recurring_count': 3,
          'recurring_percentage': 51.35,
          'regular_amount': '9000.00',
          'regular_count': 9,
          'regular_percentage': 48.65,
        },
        'period_comparison': {
          'previous_start_date': '2026-04-01',
          'previous_end_date': '2026-04-30',
          'previous_expenditure': '15000.00',
          'previous_count': 10,
          'difference': '3500.00',
          'percentage_change': 23.33,
          'trend': 'increased',
        },
        'generated_at': '2026-05-31T23:59:59Z',
      };

      final rep = AdvancedReportModel.fromJson(json);
      expect(rep.reportType, 'monthly');
      expect(rep.totalExpenditure, 18500.00);
      expect(rep.totalExpenses, 12);
      expect(rep.averageDailySpending, 596.77);
      expect(rep.highestSpendingCategory?.category, 'Bills');
      expect(rep.categoryBreakdown.length, 2);
      expect(rep.recurringVsRegular.recurringAmount, 9500.00);
      expect(rep.recurringVsRegular.regularAmount, 9000.00);
      expect(rep.periodComparison?.trend, 'increased');
      expect(rep.periodComparison?.difference, 3500.00);
      expect(rep.formattedTotalExpenditure, 'PKR 18500.00');
    });
  });
}
