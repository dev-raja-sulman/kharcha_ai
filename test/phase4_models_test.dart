import 'package:flutter_test/flutter_test.dart';
import 'package:kharcha_ai/models/analytics_model.dart';
import 'package:kharcha_ai/models/budget_model.dart';

void main() {
  group('Phase 4 BudgetModel & AnalyticsModel Tests', () {
    test('BudgetModel.fromJson correctly parses fields and calculations', () {
      final json = {
        'id': 12,
        'user_id': 3,
        'name': 'October Grocery Cap',
        'amount': '25000.00',
        'category': 'Food',
        'month': 10,
        'year': 2026,
        'start_date': '2026-10-01',
        'end_date': '2026-10-31',
        'spent': '20500.00',
        'remaining': '4500.00',
        'percentage_used': 82.0,
        'alert_level': 'warning_80',
        'alert_message': 'Warning: You have reached 80% threshold',
        'created_at': '2026-10-01T00:00:00Z',
        'updated_at': '2026-10-01T00:00:00Z',
      };

      final b = BudgetModel.fromJson(json);
      expect(b.id, 12);
      expect(b.name, 'October Grocery Cap');
      expect(b.amount, 25000.00);
      expect(b.category, 'Food');
      expect(b.spent, 20500.00);
      expect(b.remaining, 4500.00);
      expect(b.percentageUsed, 82.0);
      expect(b.alertLevel, 'warning_80');
      expect(b.isOverBudget, isFalse);
      expect(b.formattedAmount, 'PKR 25000.00');
    });

    test('SpendingAnalyticsModel.fromJson correctly parses MoM and categories', () {
      final json = {
        'month': 10,
        'year': 2026,
        'total_spent': '45000.00',
        'total_transactions': 18,
        'average_daily_spending': '1500.00',
        'highest_spending_category': {
          'category': 'Food',
          'amount': '25000.00',
          'percentage': 55.56,
          'count': 10,
        },
        'category_breakdown': [
          {
            'category': 'Food',
            'amount': '25000.00',
            'percentage': 55.56,
            'count': 10,
          },
          {
            'category': 'Bills',
            'amount': '20000.00',
            'percentage': 44.44,
            'count': 8,
          }
        ],
        'month_comparison': {
          'current_month_total': '45000.00',
          'previous_month_total': '40000.00',
          'difference': '5000.00',
          'percentage_change': 12.5,
          'trend': 'increased',
        }
      };

      final ana = SpendingAnalyticsModel.fromJson(json);
      expect(ana.totalSpent, 45000.00);
      expect(ana.totalTransactions, 18);
      expect(ana.averageDailySpending, 1500.00);
      expect(ana.highestCategory?.category, 'Food');
      expect(ana.categoryBreakdown.length, 2);
      expect(ana.monthComparison.percentageChange, 12.5);
      expect(ana.monthComparison.trend, 'increased');
    });
  });
}
