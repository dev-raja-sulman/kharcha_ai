import 'package:flutter_test/flutter_test.dart';
import 'package:kharcha_ai/models/financial_advisor_model.dart';

void main() {
  group('Phase 6 Financial Advisor Models Serialization Tests', () {
    test('AdvisorOverviewModel.fromJson parses complete ledger metrics', () {
      final json = {
        'total_income_this_month': '150000.00',
        'total_expenses_this_month': '65000.00',
        'net_cashflow': '85000.00',
        'savings_rate': 56.7,
        'active_goals_count': 2,
        'total_savings_accumulated': '50000.00',
        'pending_bills_count': 3,
        'pending_bills_total': '14500.00',
        'overdue_bills_count': 0,
        'financial_health_score': 85,
        'financial_health_status': 'Healthy',
      };

      final overview = AdvisorOverviewModel.fromJson(json);
      expect(overview.totalIncomeThisMonth, 150000.00);
      expect(overview.totalExpensesThisMonth, 65000.00);
      expect(overview.netCashflow, 85000.00);
      expect(overview.savingsRate, 56.7);
      expect(overview.activeGoalsCount, 2);
      expect(overview.totalSavingsAccumulated, 50000.00);
      expect(overview.pendingBillsCount, 3);
      expect(overview.pendingBillsTotal, 14500.00);
      expect(overview.overdueBillsCount, 0);
      expect(overview.financialHealthScore, 85);
      expect(overview.financialHealthStatus, 'Healthy');
    });

    test('AdvisorInsightsModel.fromJson parses insights and recommendations', () {
      final json = {
        'summary_headline': 'Strong financial position with PKR 85,000 surplus.',
        'provider_used': 'gemini (gemini-1.5-flash)',
        'key_recommendation': 'Allocate 40% of surplus towards emergency savings.',
        'insights': [
          {
            'type': 'strength',
            'title': 'Positive Monthly Cashflow',
            'description': 'You saved 56.7% of your earnings.',
            'impact': 'high',
          },
          {
            'type': 'alert',
            'title': 'High Food Spending',
            'description': 'Food accounts for 38% of total expenses.',
            'impact': 'medium',
          }
        ]
      };

      final insights = AdvisorInsightsModel.fromJson(json);
      expect(insights.summaryHeadline, 'Strong financial position with PKR 85,000 surplus.');
      expect(insights.providerUsed, 'gemini (gemini-1.5-flash)');
      expect(insights.keyRecommendation, 'Allocate 40% of surplus towards emergency savings.');
      expect(insights.insights.length, 2);
      expect(insights.insights[0].type, 'strength');
      expect(insights.insights[1].type, 'alert');
    });

    test('AdvisorChatResponseModel.fromJson parses reply, metrics, and suggested followups', () {
      final json = {
        'reply': 'Yes, you have sufficient monthly surplus of PKR 85,000 to afford this expense.',
        'provider_used': 'deterministic_rule_engine',
        'grounded_metrics': {
          'total_income': 150000.0,
          'net_cashflow': 85000.0,
          'savings_rate_pct': 56.7,
        },
        'suggested_followups': [
          'Can I afford a laptop for PKR 150,000?',
          'How can I boost my savings rate?',
        ],
      };

      final chat = AdvisorChatResponseModel.fromJson(json);
      expect(chat.reply, contains('sufficient monthly surplus'));
      expect(chat.providerUsed, 'deterministic_rule_engine');
      expect(chat.groundedMetrics['net_cashflow'], 85000.0);
      expect(chat.suggestedFollowups.length, 2);
    });
  });
}
