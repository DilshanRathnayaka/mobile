import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CurrencyInfo {
  final String code;
  final String symbol;
  final String name;
  final double rateToUsd; // e.g. 1 USDT = 305 LKR

  const CurrencyInfo({
    required this.code,
    required this.symbol,
    required this.name,
    required this.rateToUsd,
  });

  double convertFromUsd(double amountInUsd) => amountInUsd * rateToUsd;
  double convertToUsd(double amountInCurrency) => rateToUsd > 0 ? amountInCurrency / rateToUsd : amountInCurrency;
  String format(num amount) => '$symbol$amount';
}

class SupportedCurrencies {
  static const usdt = CurrencyInfo(code: 'USDT', symbol: 'USDT', name: 'Tether', rateToUsd: 1.0);
  static const usd = usdt; // Backward-compatibility alias
  static const lkr = CurrencyInfo(code: 'LKR', symbol: 'Rs ', name: 'Sri Lankan Rupee', rateToUsd: 305.0);
  static const inr = CurrencyInfo(code: 'INR', symbol: '₹ ', name: 'Indian Rupee', rateToUsd: 83.5);
  static const aed = CurrencyInfo(code: 'AED', symbol: 'AED ', name: 'UAE Dirham', rateToUsd: 3.67);
  static const eur = CurrencyInfo(code: 'EUR', symbol: '€ ', name: 'Euro', rateToUsd: 0.92);
  static const gbp = CurrencyInfo(code: 'GBP', symbol: '£ ', name: 'British Pound', rateToUsd: 0.78);
  static const aud = CurrencyInfo(code: 'AUD', symbol: 'A\$ ', name: 'Australian Dollar', rateToUsd: 1.52);
  static const cad = CurrencyInfo(code: 'CAD', symbol: 'C\$ ', name: 'Canadian Dollar', rateToUsd: 1.38);

  static const List<CurrencyInfo> all = [usdt, lkr, inr, aed, eur, gbp, aud, cad];

  static CurrencyInfo fromCode(String code) {
    final upper = code.trim().toUpperCase();
    if (upper == 'USD') return usdt;
    return all.firstWhere((c) => c.code == upper, orElse: () => usdt);
  }
}

final currencyProvider = StateNotifierProvider<CurrencyNotifier, CurrencyInfo>((ref) {
  return CurrencyNotifier();
});

class CurrencyNotifier extends StateNotifier<CurrencyInfo> {
  static const _prefKey = 'selected_currency_code';

  CurrencyNotifier() : super(SupportedCurrencies.usdt) {
    _loadCurrency();
  }

  Future<void> _loadCurrency() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final code = prefs.getString(_prefKey) ?? 'USDT';
      state = SupportedCurrencies.fromCode(code);
    } catch (_) {}
  }

  Future<void> setCurrency(CurrencyInfo currency) async {
    state = currency;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, currency.code);
    } catch (_) {}
  }
}
