import 'package:intl/intl.dart';

class CurrencyFormatter {
  static const String defaultCurrency = 'PKR';

  static const List<String> supportedCurrencies = [
    'PKR',
    'USD',
    'EUR',
    'GBP',
    'AED',
    'SAR',
    'INR',
    'CAD',
    'AUD',
  ];

  static const Map<String, String> currencyNames = {
    'PKR': 'Pakistani Rupee',
    'USD': 'US Dollar',
    'EUR': 'Euro',
    'GBP': 'British Pound',
    'AED': 'UAE Dirham',
    'SAR': 'Saudi Riyal',
    'INR': 'Indian Rupee',
    'CAD': 'Canadian Dollar',
    'AUD': 'Australian Dollar',
  };

  static const Map<String, String> currencySymbols = {
    'PKR': 'PKR',
    'USD': '\$',
    'EUR': '€',
    'GBP': '£',
    'AED': 'AED',
    'SAR': 'SAR',
    'INR': '₹',
    'CAD': 'CA\$',
    'AUD': 'AU\$',
  };

  /// Checks whether the given currency code is supported
  static bool isSupported(String? currency) {
    if (currency == null) return false;
    return supportedCurrencies.contains(currency.toUpperCase().trim());
  }

  /// Formats amount into standard display format, e.g. "PKR 50,000" or "USD 1,250.50"
  static String format(
    dynamic amount, {
    String? currency,
    bool showCode = true,
    int? decimalDigits,
    bool compact = false,
  }) {
    if (compact) {
      return formatCompact(amount, currency: currency);
    }
    if (amount == null) return '${currency ?? defaultCurrency} 0';

    double value = 0.0;
    if (amount is num) {
      value = amount.toDouble();
    } else if (amount is String) {
      value = double.tryParse(amount) ?? 0.0;
    }

    final code = (currency ?? defaultCurrency).toUpperCase().trim();
    final isWhole = value % 1 == 0;
    final digits = decimalDigits ?? (isWhole ? 0 : 2);
    final isNegative = value < 0;
    final absVal = value.abs();
    final numFormat = NumberFormat('#,##0${digits > 0 ? '.${'0' * digits}' : ''}');
    final formattedNum = numFormat.format(absVal);

    final prefix = showCode ? code : (currencySymbols[code] ?? code);
    final sign = isNegative ? '-' : '';

    return '$sign$prefix $formattedNum';
  }

  /// Formats amount with native symbol, e.g. "$1,250.50" or "Rs 50,000"
  static String formatWithSymbol(
    dynamic amount, {
    String? currency,
    int? decimalDigits,
  }) {
    if (amount == null) return '\$0';
    double value = 0.0;
    if (amount is num) {
      value = amount.toDouble();
    } else if (amount is String) {
      value = double.tryParse(amount) ?? 0.0;
    }

    final code = (currency ?? defaultCurrency).toUpperCase().trim();
    final symbol = code == 'PKR' ? 'Rs' : (currencySymbols[code] ?? code);

    final isWhole = value % 1 == 0;
    final digits = decimalDigits ?? (isWhole ? 0 : 2);
    final isNegative = value < 0;
    final absVal = value.abs();
    final numFormat = NumberFormat('#,##0${digits > 0 ? '.${'0' * digits}' : ''}');
    final formattedNum = numFormat.format(absVal);
    final sign = isNegative ? '-' : '';

    if (code == 'PKR') {
      return '$sign$symbol $formattedNum';
    } else {
      return '$sign$symbol$formattedNum';
    }
  }

  /// Formats compact for chart axes and summary cards, e.g. "PKR 50K"
  static String formatCompact(dynamic amount, {String? currency}) {
    if (amount == null) return '${currency ?? defaultCurrency} 0';

    double value = 0.0;
    if (amount is num) {
      value = amount.toDouble();
    } else if (amount is String) {
      value = double.tryParse(amount) ?? 0.0;
    }

    final code = (currency ?? defaultCurrency).toUpperCase().trim();
    final compactFmt = NumberFormat.compact();
    return '$code ${compactFmt.format(value)}';
  }

  /// Get currency symbol
  static String getSymbol(String? currency) {
    final code = (currency ?? defaultCurrency).toUpperCase().trim();
    return currencySymbols[code] ?? code;
  }

  /// Get currency full name
  static String getName(String? currency) {
    final code = (currency ?? defaultCurrency).toUpperCase().trim();
    return currencyNames[code] ?? code;
  }
}
