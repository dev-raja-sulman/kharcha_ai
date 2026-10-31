import 'package:flutter_test/flutter_test.dart';
import 'package:kharcha_ai/models/cashflow_model.dart';

void main() {
  group('Phase 6 Cashflow Models Serialization Tests', () {
    test('CashflowOverviewModel.fromJson parses fields and status correctly', () {
      final json = {
        'month': 10,
        'year': 2026,
        'currency': 'PKR',
        'total_income': '120000.00',
        'total_expenses': '45000.00',
        'net_cashflow': '75000.00',
        'savings_rate': 62.5,
        'total_budget': '60000.00',
        'remaining_budget': '15000.00',
        'budget_used_percentage': 75.0,
        'health_status': 'surplus',
        'health_title': 'Positive Cashflow Surplus',
        'health_summary': 'Great financial health! You saved PKR 75,000.',
        'daily_trends': [
          {
            'date': '2026-10-01',
            'income': '120000.00',
            'expense': '5000.00',
            'net': '115000.00',
          }
        ]
      };

      final model = CashflowOverviewModel.fromJson(json);
      expect(model.month, 10);
      expect(model.year, 2026);
      expect(model.totalIncome, 120000.00);
      expect(model.totalExpenses, 45000.00);
      expect(model.netCashflow, 75000.00);
      expect(model.savingsRate, 62.5);
      expect(model.totalBudget, 60000.00);
      expect(model.remainingBudget, 15000.00);
      expect(model.healthStatus, 'surplus');
      expect(model.dailyTrends.length, 1);
      expect(model.dailyTrends.first.net, 115000.00);
    });

    test('CashflowOverviewModel handles null budgets and empty trends', () {
      final json = {
        'month': 10,
        'year': 2026,
        'total_income': '0.00',
        'total_expenses': '0.00',
        'net_cashflow': '0.00',
        'savings_rate': 0.0,
        'total_budget': null,
        'remaining_budget': null,
        'budget_used_percentage': null,
        'health_status': 'no_data',
        'health_title': 'No Activity',
        'health_summary': 'No transactions recorded',
        'daily_trends': []
      };

      final model = CashflowOverviewModel.fromJson(json);
      expect(model.totalIncome, 0.0);
      expect(model.totalExpenses, 0.0);
      expect(model.totalBudget, isNull);
      expect(model.remainingBudget, isNull);
      expect(model.dailyTrends, isEmpty);
    });
  });
}
