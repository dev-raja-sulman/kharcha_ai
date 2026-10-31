import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CurrencyInfo {
  final String code;
  final String symbol;
  final String name;
  final String flag;

  const CurrencyInfo({
    required this.code,
    required this.symbol,
    required this.name,
    required this.flag,
  });
}

class CurrencyController extends ChangeNotifier {
  static final CurrencyController instance = CurrencyController._internal();
  CurrencyController._internal();

  static const String _prefKey = 'kharcha_currency_code';

  static const List<CurrencyInfo> supportedCurrencies = [
    CurrencyInfo(code: 'PKR', symbol: 'Rs', name: 'Pakistani Rupee', flag: '🇵🇰'),
    CurrencyInfo(code: 'USD', symbol: '\$', name: 'US Dollar', flag: '🇺🇸'),
    CurrencyInfo(code: 'EUR', symbol: '€', name: 'Euro', flag: '🇪🇺'),
    CurrencyInfo(code: 'GBP', symbol: '£', name: 'British Pound', flag: '🇬🇧'),
    CurrencyInfo(code: 'AED', symbol: 'AED', name: 'UAE Dirham', flag: '🇦🇪'),
    CurrencyInfo(code: 'SAR', symbol: 'SAR', name: 'Saudi Riyal', flag: '🇸🇦'),
    CurrencyInfo(code: 'CAD', symbol: 'CA\$', name: 'Canadian Dollar', flag: '🇨🇦'),
    CurrencyInfo(code: 'INR', symbol: '₹', name: 'Indian Rupee', flag: '🇮🇳'),
    CurrencyInfo(code: 'AUD', symbol: 'A\$', name: 'Australian Dollar', flag: '🇦🇺'),
  ];

  CurrencyInfo _current = supportedCurrencies.first;

  CurrencyInfo get current => _current;
  String get code => _current.code;
  String get symbol => _current.symbol;

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedCode = prefs.getString(_prefKey);
      if (savedCode != null) {
        final match = supportedCurrencies.firstWhere(
          (c) => c.code == savedCode,
          orElse: () => supportedCurrencies.first,
        );
        _current = match;
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> setCurrency(CurrencyInfo currency) async {
    if (_current.code == currency.code) return;
    _current = currency;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, currency.code);
    } catch (_) {}
  }

  String format(double amount, {bool showDecimals = true, bool compact = false}) {
    if (compact && amount.abs() >= 1000000) {
      return '$_currentSymbol ${(amount / 1000000).toStringAsFixed(1)}M';
    } else if (compact && amount.abs() >= 1000) {
      return '$_currentSymbol ${(amount / 1000).toStringAsFixed(1)}k';
    }
    final formatter = NumberFormat(
      showDecimals ? '#,##0.00' : '#,##0',
      'en_US',
    );
    return '$_currentSymbol ${formatter.format(amount)}';
  }

  String get _currentSymbol => _current.code;
}
