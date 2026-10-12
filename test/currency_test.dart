import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/providers/currency_provider.dart';

void main() {
  group('CurrencyProvider & CurrencyInfo Tests', () {
    test('Supported currencies list includes USDT and LKR', () {
      final currencies = SupportedCurrencies.all;
      final usdt = currencies.firstWhere((c) => c.code == 'USDT');
      final lkr = currencies.firstWhere((c) => c.code == 'LKR');

      expect(usdt.code, equals('USDT'));
      expect(usdt.rateToUsd, equals(1.0));

      expect(lkr.symbol, equals('Rs '));
      expect(lkr.rateToUsd, greaterThan(250.0));
    });

    test('Conversion from and to USDT/USD is consistent', () {
      final lkr = SupportedCurrencies.lkr;
      const testUsdt = 100.0;
      final lkrValue = testUsdt * lkr.rateToUsd;

      expect(lkrValue, equals(30500.0));
      expect(lkrValue / lkr.rateToUsd, equals(testUsdt));
    });

    test('fromCode returns corresponding currency or fallback', () {
      expect(SupportedCurrencies.fromCode('USDT').code, equals('USDT'));
      expect(SupportedCurrencies.fromCode('USD').code, equals('USDT'));
      expect(SupportedCurrencies.fromCode('LKR').code, equals('LKR'));
      expect(SupportedCurrencies.fromCode('lkr').code, equals('LKR'));
      expect(SupportedCurrencies.fromCode('INVALID').code, equals('USDT'));
    });
  });
}
