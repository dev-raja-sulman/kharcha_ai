import 'package:flutter_test/flutter_test.dart';
import 'package:kharcha_ai/models/receipt_scan_model.dart';

void main() {
  group('ReceiptScanModel Serialization Tests', () {
    test('ReceiptScanModel.fromJson parses complete AI extraction payload correctly', () {
      final json = {
        'merchant_name': 'KFC Gulberg Lahore',
        'amount': '1850.50',
        'transaction_date': '2026-10-28',
        'currency': 'PKR',
        'suggested_category': 'Food',
        'category_explanation': 'Suggested as Food based on identified terms: kfc, burger',
        'line_items': [
          {
            'description': 'Zinger Combo Box',
            'amount': '950.00',
            'quantity': 1,
          },
          {
            'description': 'Hot Wings 10 Pcs',
            'amount': '900.50',
            'quantity': 1,
          }
        ],
        'confidence': 0.94,
        'warnings': ['Minor fold detected in bottom margin'],
        'raw_text_preview': 'KFC Gulberg\nTotal: 1850.50',
        'provider_used': 'gemini (gemini-1.5-flash)',
      };

      final result = ReceiptScanModel.fromJson(json);

      expect(result.merchantName, 'KFC Gulberg Lahore');
      expect(result.amount, 1850.50);
      expect(result.transactionDate, DateTime.parse('2026-10-28'));
      expect(result.currency, 'PKR');
      expect(result.suggestedCategory, 'Food');
      expect(result.categoryExplanation, contains('Food'));
      expect(result.confidence, 0.94);
      expect(result.warnings.length, 1);
      expect(result.providerUsed, 'gemini (gemini-1.5-flash)');
      expect(result.lineItems.length, 2);
      expect(result.lineItems[0].description, 'Zinger Combo Box');
      expect(result.lineItems[0].amount, 950.00);
      expect(result.lineItems[1].quantity, 1);
    });

    test('ReceiptScanModel.fromJson handles null or partial values gracefully without errors', () {
      final json = {
        'merchant_name': null,
        'amount': null,
        'transaction_date': null,
        'currency': 'PKR',
        'suggested_category': 'Other',
        'line_items': [],
        'confidence': 0.25,
        'warnings': ['Could not determine total amount'],
        'provider_used': 'rule_based',
      };

      final result = ReceiptScanModel.fromJson(json);

      expect(result.merchantName, isNull);
      expect(result.amount, isNull);
      expect(result.transactionDate, isNull);
      expect(result.currency, 'PKR');
      expect(result.suggestedCategory, 'Other');
      expect(result.confidence, 0.25);
      expect(result.warnings.length, 1);
      expect(result.providerUsed, 'rule_based');
      expect(result.lineItems, isEmpty);
    });
  });
}
