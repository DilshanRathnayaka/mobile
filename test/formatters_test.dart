import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/utils/formatters.dart';
import 'package:mobile/providers/currency_provider.dart';

void main() {
  group('Formatters Tests', () {
    test('cryptoAmount preserves tiny decimal tokens without rounding to zero', () {
      expect(Formatters.cryptoAmount(0.00001045), equals('0.00001045'));
      expect(Formatters.cryptoAmount(0.00000001), equals('0.00000001'));
      expect(Formatters.cryptoAmount(0.00000012), equals('0.00000012'));
      expect(Formatters.cryptoAmount(1.2345), equals('1.2345'));
      expect(Formatters.cryptoAmount(1050.5), equals('1,050.5000'));
      expect(Formatters.cryptoAmount(10.0), equals('10'));
    });

    test('currency formats USDT and LKR with appropriate symbols', () {
      final usdtFormatted = Formatters.currency(1234.56, SupportedCurrencies.usdt);
      expect(usdtFormatted, contains('1,234.56 USDT'));

      final lkrFormatted = Formatters.currency(100.0, SupportedCurrencies.lkr);
      expect(lkrFormatted, contains('Rs'));
    });

    test('percentage includes positive + sign and negative - sign', () {
      expect(Formatters.percentage(5.25), equals('+5.25%'));
      expect(Formatters.percentage(-3.14), equals('-3.14%'));
      expect(Formatters.percentage(0.0), equals('+0.00%'));
    });

    test('cryptoPrice formats sub-cent tokens with 8 decimals', () {
      final microPrice = Formatters.cryptoPrice(0.00001234, SupportedCurrencies.usdt);
      expect(microPrice, contains('0.00001234'));
    });
  });
}
