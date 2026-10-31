import 'package:flutter_test/flutter_test.dart';
import 'package:kharcha_ai/models/dashboard_model.dart';

void main() {
  group('Phase 6 Dashboard Financial Summary Model Tests', () {
    test('DashboardSummaryCardsModel parses correctly without deficit', () {
      final json = {
        'monthly_income': '150000.00',
        'monthly_expenses': '65000.00',
        'net_cashflow': '85000.00',
        'monthly_savings': '85000.00',
        'savings_rate': 56.67,
        'is_deficit': false,
        'deficit_warning_message': null,
      };

      final cards = DashboardSummaryCardsModel.fromJson(json);
      expect(cards.monthlyIncome, 150000.0);
      expect(cards.monthlyExpenses, 65000.0);
      expect(cards.netCashflow, 85000.0);
      expect(cards.monthlySavings, 85000.0);
      expect(cards.savingsRate, 56.67);
      expect(cards.isDeficit, false);
      expect(cards.deficitWarningMessage, isNull);
    });

    test('DashboardSummaryCardsModel correctly parses deficit and warning', () {
      final json = {
        'monthly_income': '50000.00',
        'monthly_expenses': '75000.00',
        'net_cashflow': '-25000.00',
        'monthly_savings': '0.00',
        'savings_rate': 0.0,
        'is_deficit': true,
        'deficit_warning_message': 'Your expenses exceed your income by PKR 25,000 this month.',
      };

      final cards = DashboardSummaryCardsModel.fromJson(json);
      expect(cards.monthlyIncome, 50000.0);
      expect(cards.monthlyExpenses, 75000.0);
      expect(cards.netCashflow, -25000.0);
      expect(cards.monthlySavings, 0.0);
      expect(cards.savingsRate, 0.0);
      expect(cards.isDeficit, true);
      expect(cards.deficitWarningMessage, contains('PKR 25,000'));
    });

    test('IncomeVsExpenseComparisonModel parses month-over-month numbers', () {
      final json = {
        'current_month_income': '120000.00',
        'current_month_expenses': '80000.00',
        'current_month_net': '40000.00',
        'prev_month_income': '100000.00',
        'prev_month_expenses': '85000.00',
        'prev_month_net': '15000.00',
      };

      final comp = IncomeVsExpenseComparisonModel.fromJson(json);
      expect(comp.currentMonthIncome, 120000.0);
      expect(comp.currentMonthExpenses, 80000.0);
      expect(comp.currentMonthNet, 40000.0);
      expect(comp.prevMonthIncome, 100000.0);
      expect(comp.prevMonthExpenses, 85000.0);
      expect(comp.prevMonthNet, 15000.0);
    });

    test('DashboardCategorySpendingModel parses category breakdown items', () {
      final json = {
        'category': 'Food',
        'amount': '25000.00',
        'percentage': 38.46,
        'transaction_count': 12,
      };

      final cat = DashboardCategorySpendingModel.fromJson(json);
      expect(cat.category, 'Food');
      expect(cat.amount, 25000.0);
      expect(cat.percentage, 38.46);
      expect(cat.transactionCount, 12);
    });

    test('DashboardBudgetStatusModel parses monthly budget metrics', () {
      final json = {
        'total_budget': '100000.00',
        'budget_spent': '65000.00',
        'remaining_budget': '35000.00',
        'percentage_used': 65.0,
        'is_over_budget': false,
      };

      final budget = DashboardBudgetStatusModel.fromJson(json);
      expect(budget.totalBudget, 100000.0);
      expect(budget.budgetSpent, 65000.0);
      expect(budget.remainingBudget, 35000.0);
      expect(budget.percentageUsed, 65.0);
      expect(budget.isOverBudget, false);
    });

    test('DashboardFinancialSummaryModel parses complete nested payload', () {
      final payload = {
        'month': 10,
        'year': 2026,
        'currency': 'PKR',
        'summary_cards': {
          'monthly_income': '150000.00',
          'monthly_expenses': '65000.00',
          'net_cashflow': '85000.00',
          'monthly_savings': '85000.00',
          'savings_rate': 56.67,
          'is_deficit': false,
          'deficit_warning_message': null,
        },
        'comparison': {
          'current_month_income': '150000.00',
          'current_month_expenses': '65000.00',
          'current_month_net': '85000.00',
          'prev_month_income': '140000.00',
          'prev_month_expenses': '70000.00',
          'prev_month_net': '70000.00',
        },
        'category_breakdown': [
          {
            'category': 'Food',
            'amount': '25000.00',
            'percentage': 38.5,
            'transaction_count': 8,
          },
          {
            'category': 'Transport',
            'amount': '15000.00',
            'percentage': 23.1,
            'transaction_count': 5,
          },
        ],
        'daily_trends': [],
        'recent_incomes': [
          {
            'id': 1,
            'user_id': 10,
            'title': 'Salary',
            'amount': '150000.00',
            'currency': 'PKR',
            'income_date': '2026-10-01',
            'payment_method': 'Bank Transfer',
            'created_at': '2026-10-01T10:00:00Z',
            'updated_at': '2026-10-01T10:00:00Z',
          }
        ],
        'recent_expenses': [
          {
            'id': 101,
            'user_id': 10,
            'title': 'Groceries',
            'amount': '8500.00',
            'category': 'Food',
            'currency': 'PKR',
            'expense_date': '2026-10-15',
            'payment_method': 'Cash',
            'created_at': '2026-10-15T12:00:00Z',
          }
        ],
        'upcoming_bills': [
          {
            'id': 1,
            'user_id': 10,
            'title': 'Electricity Bill',
            'amount': '12500.00',
            'category': 'Utilities',
            'currency': 'PKR',
            'due_date': '2026-10-25',
            'frequency': 'monthly',
            'is_paid': false,
            'reminder_enabled': true,
            'created_at': '2026-10-01T10:00:00Z',
            'updated_at': '2026-10-01T10:00:00Z',
          }
        ],
        'budget_status': {
          'total_budget': '100000.00',
          'budget_spent': '65000.00',
          'remaining_budget': '35000.00',
          'percentage_used': 65.0,
          'is_over_budget': false,
        },
        'ai_insights': [
          {
            'type': 'strength',
            'title': 'Positive Cashflow',
            'description': 'Your savings rate of 56.7% is healthy.',
            'impact': 'positive',
          }
        ],
        'health_status': 'surplus',
        'health_title': 'Cashflow Surplus',
        'health_summary': 'You are operating with positive monthly net cashflow.',
      };

      final summary = DashboardFinancialSummaryModel.fromJson(payload);
      expect(summary.month, 10);
      expect(summary.year, 2026);
      expect(summary.currency, 'PKR');
      expect(summary.summaryCards.monthlyIncome, 150000.0);
      expect(summary.comparison.currentMonthIncome, 150000.0);
      expect(summary.categoryBreakdown.length, 2);
      expect(summary.recentIncomes.length, 1);
      expect(summary.recentIncomes.first.title, 'Salary');
      expect(summary.recentExpenses.length, 1);
      expect(summary.recentExpenses.first.title, 'Groceries');
      expect(summary.upcomingBills.length, 1);
      expect(summary.budgetStatus?.totalBudget, 100000.0);
      expect(summary.aiInsights.length, 1);
      expect(summary.healthStatus, 'surplus');

      final formattedStr = summary.formatAmount(50000.0);
      expect(formattedStr, contains('PKR'));
      expect(formattedStr, contains('50,000'));
    });
  });
}
