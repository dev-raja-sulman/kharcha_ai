import 'package:flutter_test/flutter_test.dart';
import 'package:kharcha_ai/models/saving_goal_model.dart';

void main() {
  group('Phase 6 Saving Goal Models Serialization Tests', () {
    test('SavingGoalModel.fromJson parses fields and computes getters', () {
      final json = {
        'id': 1,
        'user_id': 10,
        'title': 'Buy a Laptop',
        'description': 'MacBook Pro for work',
        'target_amount': '150000.00',
        'current_amount': '30000.00',
        'start_date': '2026-10-01',
        'target_date': '2026-12-31',
        'status': 'in_progress',
        'remaining_amount': '120000.00',
        'progress_percentage': 20.0,
        'created_at': '2026-10-01T10:00:00Z',
        'updated_at': '2026-10-01T10:00:00Z',
      };

      final goal = SavingGoalModel.fromJson(json);
      expect(goal.id, 1);
      expect(goal.userId, 10);
      expect(goal.title, 'Buy a Laptop');
      expect(goal.targetAmount, 150000.00);
      expect(goal.currentAmount, 30000.00);
      expect(goal.remainingAmount, 120000.00);
      expect(goal.progressPercentage, 20.0);
      expect(goal.isCompleted, false);
    });

    test('SavingGoalModel.isCompleted returns true when target is reached', () {
      final json = {
        'id': 2,
        'user_id': 10,
        'title': 'Emergency Fund',
        'target_amount': '50000.00',
        'current_amount': '50000.00',
        'start_date': '2026-08-01',
        'target_date': '2026-10-31',
        'status': 'completed',
        'remaining_amount': '0.00',
        'progress_percentage': 100.0,
        'created_at': '2026-08-01T10:00:00Z',
        'updated_at': '2026-10-31T10:00:00Z',
      };

      final goal = SavingGoalModel.fromJson(json);
      expect(goal.isCompleted, true);
    });

    test('ContributionModel.fromJson parses amount and dates correctly', () {
      final json = {
        'id': 5,
        'goal_id': 1,
        'user_id': 10,
        'amount': '25000.00',
        'contribution_date': '2026-10-15',
        'notes': 'Mid-month freelance payment',
        'created_at': '2026-10-15T12:00:00Z',
      };

      final contrib = ContributionModel.fromJson(json);
      expect(contrib.id, 5);
      expect(contrib.goalId, 1);
      expect(contrib.amount, 25000.00);
      expect(contrib.notes, 'Mid-month freelance payment');
      expect(contrib.contributionDate.day, 15);
    });

    test('SavingGoalListModel.fromJson parses list and total savings', () {
      final json = {
        'total': 1,
        'total_savings': '80000.00',
        'items': [
          {
            'id': 1,
            'user_id': 10,
            'title': 'Bike Upgrade',
            'target_amount': '100000.00',
            'current_amount': '80000.00',
            'start_date': '2026-09-01',
            'target_date': '2026-11-30',
            'status': 'in_progress',
            'remaining_amount': '20000.00',
            'progress_percentage': 80.0,
            'created_at': '2026-09-01T10:00:00Z',
            'updated_at': '2026-10-30T10:00:00Z',
          }
        ]
      };

      final list = SavingGoalListModel.fromJson(json);
      expect(list.total, 1);
      expect(list.totalSavings, 80000.00);
      expect(list.items.length, 1);
      expect(list.items.first.title, 'Bike Upgrade');
    });
  });
}
