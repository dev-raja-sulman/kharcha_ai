import 'package:flutter_test/flutter_test.dart';
import 'package:kharcha_ai/core/utils/currency_formatter.dart';
import 'package:kharcha_ai/models/expense_model.dart';
import 'package:kharcha_ai/models/user_model.dart';

void main() {
  group('Multi-Currency Support & Formatting Tests', () {
    test('CurrencyFormatter validates 9 supported currencies strictly', () {
      expect(CurrencyFormatter.supportedCurrencies, [
        'PKR',
        'USD',
        'EUR',
        'GBP',
        'AED',
        'SAR',
        'INR',
        'CAD',
        'AUD',
      ]);
      expect(CurrencyFormatter.supportedCurrencies.length, 9);
      expect(CurrencyFormatter.defaultCurrency, 'PKR');

      expect(CurrencyFormatter.isSupported('PKR'), isTrue);
      expect(CurrencyFormatter.isSupported('USD'), isTrue);
      expect(CurrencyFormatter.isSupported('EUR'), isTrue);
      expect(CurrencyFormatter.isSupported('JPY'), isFalse);
    });

    test('CurrencyFormatter formats amounts with correct currency codes and symbols', () {
      expect(CurrencyFormatter.format(50000, currency: 'PKR', decimalDigits: 0), 'PKR 50,000');
      expect(CurrencyFormatter.format(92020, currency: 'PKR', decimalDigits: 0), 'PKR 92,020');
      expect(CurrencyFormatter.format(-42020, currency: 'PKR', decimalDigits: 0), '-PKR 42,020');
      expect(CurrencyFormatter.format(1250.50, currency: 'USD'), 'USD 1,250.50');
      expect(CurrencyFormatter.getSymbol('USD'), '\$');
      expect(CurrencyFormatter.getSymbol('PKR'), 'PKR');
      expect(CurrencyFormatter.getName('USD'), 'US Dollar');
      expect(CurrencyFormatter.getName('PKR'), 'Pakistani Rupee');
    });

    test('UserModel parses preferredCurrency and defaults to PKR', () {
      final defaultUserJson = {
        'id': 10,
        'email': 'newuser@kharcha.ai',
        'full_name': 'New User',
        'is_active': true,
        'created_at': '2026-10-28T07:00:00Z',
      };
      final userDefault = UserModel.fromJson(defaultUserJson);
      expect(userDefault.preferredCurrency, 'PKR');

      final usdUserJson = {
        'id': 11,
        'email': 'usduser@kharcha.ai',
        'full_name': 'Global User',
        'preferred_currency': 'USD',
        'is_active': true,
        'created_at': '2026-10-28T07:00:00Z',
      };
      final userUsd = UserModel.fromJson(usdUserJson);
      expect(userUsd.preferredCurrency, 'USD');
    });

    test('ExpenseModel preserves original transaction currency', () {
      final json = {
        'id': 201,
        'user_id': 1,
        'title': 'Domain renewal',
        'amount': '15.00',
        'currency': 'USD',
        'category': 'Services',
        'expense_date': '2026-10-15',
        'payment_method': 'Credit Card',
        'created_at': '2026-10-15T10:00:00Z',
        'updated_at': '2026-10-15T10:00:00Z',
      };

      final expense = ExpenseModel.fromJson(json);
      expect(expense.currency, 'USD');
      expect(expense.amount, 15.00);
      expect(expense.formattedAmount, 'USD 15');
    });
  });
}
