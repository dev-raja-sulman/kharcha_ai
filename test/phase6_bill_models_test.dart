import 'package:flutter_test/flutter_test.dart';
import 'package:kharcha_ai/models/bill_model.dart';

void main() {
  group('Phase 6 Bill Models Serialization Tests', () {
    test('BillModel.fromJson parses fields and computes getters', () {
      final json = {
        'id': 101,
        'user_id': 5,
        'title': 'LESCO Electricity Bill',
        'category': 'Electricity',
        'amount': '12500.50',
        'due_date': '2026-11-05',
        'status': 'unpaid',
        'frequency': 'monthly',
        'reminder_enabled': true,
        'paid_date': null,
        'linked_expense_id': null,
        'is_overdue': false,
        'created_at': '2026-10-31T10:00:00Z',
        'updated_at': '2026-10-31T10:00:00Z',
      };

      final bill = BillModel.fromJson(json);
      expect(bill.id, 101);
      expect(bill.userId, 5);
      expect(bill.title, 'LESCO Electricity Bill');
      expect(bill.category, 'Electricity');
      expect(bill.amount, 12500.50);
      expect(bill.status, 'unpaid');
      expect(bill.isPending, true);
      expect(bill.isPaid, false);
      expect(bill.isOverdue, false);
      expect(bill.reminderEnabled, true);
    });

    test('BillModel correctly identifies paid status and linked expense', () {
      final json = {
        'id': 102,
        'user_id': 5,
        'title': 'Nayatel Fiber Internet',
        'category': 'Internet',
        'amount': '4200.00',
        'due_date': '2026-10-25',
        'status': 'paid',
        'frequency': 'monthly',
        'reminder_enabled': true,
        'paid_date': '2026-10-24',
        'linked_expense_id': 55,
        'is_overdue': false,
        'created_at': '2026-10-15T10:00:00Z',
        'updated_at': '2026-10-24T12:00:00Z',
      };

      final bill = BillModel.fromJson(json);
      expect(bill.isPaid, true);
      expect(bill.isPending, false);
      expect(bill.linkedExpenseId, 55);
      expect(bill.paidDate, isNotNull);
    });

    test('BillListModel.fromJson parses list and totals', () {
      final json = {
        'total': 2,
        'total_amount': '16700.50',
        'items': [
          {
            'id': 1,
            'user_id': 5,
            'title': 'Bill 1',
            'category': 'Electricity',
            'amount': '10000.00',
            'due_date': '2026-11-01',
            'status': 'unpaid',
            'frequency': 'monthly',
            'reminder_enabled': true,
            'is_overdue': false,
            'created_at': '2026-10-31T10:00:00Z',
            'updated_at': '2026-10-31T10:00:00Z',
          },
          {
            'id': 2,
            'user_id': 5,
            'title': 'Bill 2',
            'category': 'Gas',
            'amount': '6700.50',
            'due_date': '2026-10-20',
            'status': 'overdue',
            'frequency': 'monthly',
            'reminder_enabled': true,
            'is_overdue': true,
            'created_at': '2026-10-10T10:00:00Z',
            'updated_at': '2026-10-31T10:00:00Z',
          }
        ]
      };

      final listModel = BillListModel.fromJson(json);
      expect(listModel.total, 2);
      expect(listModel.totalAmount, 16700.50);
      expect(listModel.items.length, 2);
      expect(listModel.items[1].isOverdue, true);
    });

    test('BillSummaryModel.fromJson parses overview counts and upcoming bills', () {
      final json = {
        'total_pending_amount': '10000.00',
        'pending_count': 1,
        'total_overdue_amount': '6700.50',
        'overdue_count': 1,
        'total_paid_this_month': '15000.00',
        'paid_count_this_month': 2,
        'upcoming_bills': [
          {
            'id': 1,
            'user_id': 5,
            'title': 'Bill 1',
            'category': 'Electricity',
            'amount': '10000.00',
            'due_date': '2026-11-01',
            'status': 'unpaid',
            'frequency': 'monthly',
            'reminder_enabled': true,
            'is_overdue': false,
            'created_at': '2026-10-31T10:00:00Z',
            'updated_at': '2026-10-31T10:00:00Z',
          }
        ]
      };

      final summary = BillSummaryModel.fromJson(json);
      expect(summary.totalPendingAmount, 10000.00);
      expect(summary.pendingCount, 1);
      expect(summary.totalOverdueAmount, 6700.50);
      expect(summary.overdueCount, 1);
      expect(summary.totalPaidThisMonth, 15000.00);
      expect(summary.paidCountThisMonth, 2);
      expect(summary.upcomingBills.length, 1);
    });
  });
}
